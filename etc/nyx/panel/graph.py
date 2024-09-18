# Copyright 2010-2020, Damian Johnson and The Tor Project
# See LICENSE for licensing information

"""
Graphs of tor related statistics. For example...

Downloaded (0.0 B/sec):           Uploaded (0.0 B/sec):
  34                                30
                            *                                 *
                    **  *   *                          *      **
      *   *  *      ** **   **          ***  **       ** **   **
     *********      ******  ******     *********      ******  ******
   0 ************ ****************   0 ************ ****************
         25s  50   1m   1.6  2.0           25s  50   1m   1.6  2.0
"""

import copy
import functools
import threading
import time

import nyx.curses
import nyx.panel
import nyx.popups
import nyx.tracker

from nyx import nyx_interface, tor_controller, join, show_message
from nyx.curses import RED, GREEN, CYAN, BOLD, HIGHLIGHT
from nyx.menu import MenuItem, Submenu, RadioMenuItem, RadioGroup
from stem.control import EventType, Listener
from stem.util import conf, enum, log, str_tools, system

GraphStat = enum.Enum(('BANDWIDTH', 'bandwidth'), ('CONNECTIONS', 'connections'), ('SYSTEM_RESOURCES', 'resources'))
Interval = enum.Enum(('EACH_SECOND', 'each second'), ('FIVE_SECONDS', '5 seconds'), ('THIRTY_SECONDS', '30 seconds'), ('MINUTELY', 'minutely'), ('FIFTEEN_MINUTE', '15 minute'), ('THIRTY_MINUTE', '30 minute'), ('HOURLY', 'hourly'), ('DAILY', 'daily'))
Bounds = enum.Enum(('GLOBAL_MAX', 'global_max'), ('LOCAL_MAX', 'local_max'), ('TIGHT', 'tight'))

INTERVAL_SECONDS = {
  Interval.EACH_SECOND: 1,
  Interval.FIVE_SECONDS: 5,
  Interval.THIRTY_SECONDS: 30,
  Interval.MINUTELY: 60,
  Interval.FIFTEEN_MINUTE: 900,
  Interval.THIRTY_MINUTE: 1800,
  Interval.HOURLY: 3600,
  Interval.DAILY: 86400,
}

PRIMARY_COLOR, SECONDARY_COLOR = GREEN, CYAN

ACCOUNTING_RATE = 5
DEFAULT_CONTENT_HEIGHT = 4  # space needed for labeling above and below the graph
WIDE_LABELING_GRAPH_COL = 50  # minimum graph columns to use wide spacing for x-axis labels
TITLE_UPDATE_RATE = 30


def conf_handler(key, value):
  if key == 'graph_height':
    return max(1, value)
  elif key == 'max_graph_width':
    return max(1, value)
  elif key == 'graph_stat':
    if value != 'none' and value not in GraphStat:
      log.warn("'%s' isn't a valid graph type, options are: none, %s" % (CONFIG['graph_stat'], ', '.join(GraphStat)))
      return CONFIG['graph_stat']  # keep the default
  elif key == 'graph_interval':
    if value not in Interval:
      log.warn("'%s' isn't a valid graphing interval, options are: %s" % (value, ', '.join(Interval)))
      return CONFIG['graph_interval']  # keep the default
  elif key == 'graph_bound':
    if value not in Bounds:
      log.warn("'%s' isn't a valid graph bounds, options are: %s" % (value, ', '.join(Bounds)))
      return CONFIG['graph_bound']  # keep the default


CONFIG = conf.config_dict('nyx', {
  'attr.hibernate_color': {},
  'attr.graph.title': {},
  'attr.graph.header.primary': {},
  'attr.graph.header.secondary': {},
  'graph_bound': Bounds.LOCAL_MAX,
  'graph_height': 7,
  'graph_interval': Interval.EACH_SECOND,
  'graph_stat': GraphStat.BANDWIDTH,
  'max_graph_width': 300,  # we need some sort of max size so we know how much graph data to retain
  'show_accounting': True,
  'show_bits': False,
  'show_connections': True,
}, conf_handler)


def _bandwidth_title_stats():
  controller = tor_controller()

  stats = []
  bw_rate = controller.get_effective_rate(None)
  bw_burst = controller.get_effective_rate(None, burst = True)

  if bw_rate and bw_burst:
    bw_rate_label = _size_label(bw_rate)
    bw_burst_label = _size_label(bw_burst)

    # if both are using rounded values then strip off the '.0' decimal

    if '.0' in bw_rate_label and '.0' in bw_burst_label:
      bw_rate_label = bw_rate_label.replace('.0', '')
      bw_burst_label = bw_burst_label.replace('.0', '')

    stats.append('limit: %s/s' % bw_rate_label)
    stats.append('burst: %s/s' % bw_burst_label)

  my_server_descriptor = controller.get_server_descriptor(default = None)
  observed_bw = getattr(my_server_descriptor, 'observed_bandwidth', None)

  if observed_bw:
    stats.append('observed: %s/s' % _size_label(observed_bw))

  return stats


class GraphData(object):
  """
  Graphable statistical information.

  :var int latest_value: last value we recorded
  :var int total: sum of all values we've recorded
  :var int tick: number of events we've processed
  :var dict values: mapping of intervals to an array of samplings from newest to oldest
  """

  def __init__(self, clone = None, category = None, is_primary = True):
    if clone:
      self.latest_value = clone.latest_value
      self.total = clone.total
      self.tick = clone.tick
      self.values = copy.deepcopy(clone.values)

      self._category = category
      self._is_primary = clone._is_primary
      self._in_process_value = dict(clone._in_process_value)
      self._max_value = dict(clone._max_value)
    else:
      self.latest_value = 0
      self.total = 0
      self.tick = 0
      self.values = dict([(i, CONFIG['max_graph_width'] * [0]) for i in Interval])

      self._category = category
      self._is_primary = is_primary
      self._in_process_value = dict([(i, 0) for i in Interval])
      self._max_value = dict([(i, 0) for i in Interval])  # interval => maximum value it's had

  def average(self):
    return self.total / max(1, self.tick)

  def update(self, new_value):
    bw_burst = tor_controller().get_effective_rate(None, burst = True)

    # On spike keep the last value once more.
    # Can do better, but works for now.
    if new_value > bw_burst:
      new_value = self.latest_value

    self.latest_value = new_value
    self.total += new_value
    self.tick += 1

    for interval in Interval:
      interval_seconds = INTERVAL_SECONDS[interval]
      self._in_process_value[interval] += new_value

      if self.tick % interval_seconds == 0:
        new_entry = self._in_process_value[interval] / interval_seconds
        self.values[interval] = [new_entry] + self.values[interval][:-1]
        self._max_value[interval] = max(self._max_value[interval], new_entry)
        self._in_process_value[interval] = 0

  def header(self, width):
    """
    Provides the description above a subgraph.

    :param int width: maximum length of the header

    :returns: **str** with our graph header
    """

    return self._category._header(width, self._is_primary)

  def bounds(self, bounds, interval, columns):
    """
    Range of values for the graph.

    :param Bounds bounds: boundary type for the range we want
    :param Interval interval: timing interval of the values
    :param int columns: number of values to take into account

    :returns: **tuple** of the form (min, max)
    """

    min_bound, max_bound = 0, 0
    values = self.values[interval][:columns]

    if bounds == Bounds.GLOBAL_MAX:
      max_bound = self._max_value[interval]
    elif columns > 0:
      max_bound = max(values)  # local maxima

    if bounds == Bounds.TIGHT and columns > 0:
      min_bound = min(values)

      # if the max = min pick zero so we still display something

      if min_bound == max_bound:
        min_bound = 0

    return min_bound, max_bound

  def y_axis_label(self, value):
    """
    Provides the label we should display on our y-axis.

    :param int value: value being shown on the y-axis

    :returns: **str** with our y-axis label
    """

    return self._category._y_axis_label(value, self._is_primary)


class GraphCategory(object):
  """
  Category for the graph. This maintains two subgraphs, updating them each
  second with updated stats.

  :var GraphData primary: first subgraph
  :var GraphData secondary: second subgraph
  :var float start_time: unix timestamp for when we started
  """

  def __init__(self, clone = None):
    if clone:
      self.primary = GraphData(clone.primary, category = self)
      self.secondary = GraphData(clone.secondary, category = self)
      self.start_time = clone.start_time
      self._title_stats = list(clone._title_stats)
      self._primary_header_stats = list(clone._primary_header_stats)
      self._secondary_header_stats = list(clone._secondary_header_stats)
    else:
      self.primary = GraphData(category = self, is_primary = True)
      self.secondary = GraphData(category = self, is_primary = False)
      self.start_time = time.time()
      self._title_stats = []
      self._primary_header_stats = []
      self._secondary_header_stats = []

  def stat_type(self):
    """
    Provides the GraphStat this graph is for.

    :returns: **GraphStat** of this graph
    """

    raise NotImplementedError('Should be implemented by subclasses')

  def title(self, width):
    """
    Provides a graph title that fits in the given width.

    :param int width: maximum length of the title

    :returns: **str** with our title
    """

    title = CONFIG['attr.graph.title'].get(self.stat_type(), '')
    title_stats = join(self._title_stats, ', ', width - len(title) - 4)
    return '%s (%s):' % (title, title_stats) if title_stats else title + ':'

  def bandwidth_event(self, event):
    """
    Called when it's time to process another event. All graphs use tor BW
    events to keep in sync with each other (this happens once per second).
    """

    pass

  def _header(self, width, is_primary):
    if is_primary:
      header = CONFIG['attr.graph.header.primary'].get(self.stat_type(), '')
      header_stats = self._primary_header_stats
    else:
      header = CONFIG['attr.graph.header.secondary'].get(self.stat_type(), '')
      header_stats = self._secondary_header_stats

    header_stats = join(header_stats, '', width - len(header) - 4).rstrip()
    return '%s (%s):' % (header, header_stats) if header_stats else '%s:' % header

  def _y_axis_label(self, value, is_primary):
    return str(value)


class BandwidthStats(GraphCategory):
  """
  Tracks tor's bandwidth usage.
  """

  def __init__(self, clone = None):
    GraphCategory.__init__(self, clone)
    self._title_last_updated = None

    if not clone:
      # fill in past bandwidth information

      controller = tor_controller()
      bw_entries, is_successful = controller.get_info('bw-event-cache', None), True

      if bw_entries:
        bw_burst = tor_controller().get_effective_rate(None, burst = True)
        bw_entries = bw_entries.split()

        for i in range(0, len(bw_entries)):
          entry_comp = bw_entries[i].split(',')

          if len(entry_comp) != 2 or not entry_comp[0].isdigit() or not entry_comp[1].isdigit():
            log.warn("Tor's 'GETINFO bw-event-cache' provided malformed output: %s" % bw_entries)
            is_successful = False
            break

          entry_comp_int = [int(entry_comp[0]), int(entry_comp[1])]

          if entry_comp_int[0] > bw_burst and entry_comp_int[1] > bw_burst:
            if bw_entries[i+1] and bw_entries[i-1]:
              # Calculate the average of adjacent values to replace the spike value
              entry_comp_m1 = bw_entries[i-1].split(',')
              entry_comp_p1 = bw_entries[i+1].split(',')
              avg = [int((int(entry_comp_m1[0]) + int(entry_comp_p1[0])) / 2), int((int(entry_comp_m1[1]) + int(entry_comp_p1[1])) / 2)]
              self.primary.update(avg[0])
              self.secondary.update(avg[1])
            else:
              self.primary.update(0)
              self.secondary.update(0)
          else:
            self.primary.update(entry_comp_int[0])
            self.secondary.update(entry_comp_int[1])

        if is_successful:
          log.info('Bandwidth graph has information for the last %s' % str_tools.time_label(len(bw_entries), is_long = True))

      read_total = controller.get_info('traffic/read', None)
      write_total = controller.get_info('traffic/written', None)
      start_time = system.start_time(controller.get_pid(None))

      if read_total and write_total and start_time:
        self.primary.total = int(read_total)
        self.secondary.total = int(write_total)
        self.start_time = start_time

  def stat_type(self):
    return GraphStat.BANDWIDTH

  def _y_axis_label(self, value, is_primary):
    return _size_label(value, 0)

  def bandwidth_event(self, event):
    self.primary.update(event.read)
    self.secondary.update(event.written)

    self._primary_header_stats = [
      '%-14s' % ('%s/sec' % _size_label(self.primary.latest_value)),
      '- avg: %s/sec' % _size_label(self.primary.total / (time.time() - self.start_time)),
      ', total: %s' % _size_label(self.primary.total),
    ]

    self._secondary_header_stats = [
      '%-14s' % ('%s/sec' % _size_label(self.secondary.latest_value)),
      '- avg: %s/sec' % _size_label(self.secondary.total / (time.time() - self.start_time)),
      ', total: %s' % _size_label(self.secondary.total),
    ]

    if not self._title_last_updated or time.time() - self._title_last_updated > TITLE_UPDATE_RATE:
      self._title_stats = _bandwidth_title_stats()
      self._title_last_updated = time.time()


class ConnectionStats(GraphCategory):
  """
  Tracks number of inbound and outbound connections.
  """

  def stat_type(self):
    return GraphStat.CONNECTIONS

  def bandwidth_event(self, event):
    inbound_count, outbound_count = 0, 0

    controller = tor_controller()
    or_ports = controller.get_ports(Listener.OR, [])
    dir_ports = controller.get_ports(Listener.DIR, [])
    control_ports = controller.get_ports(Listener.CONTROL, [])

    for entry in nyx.tracker.get_connection_tracker().get_value():
      if entry.local_port in or_ports or entry.local_port in dir_ports:
        inbound_count += 1
      elif entry.local_port in control_ports:
        pass  # control connection
      else:
        outbound_count += 1

    self.primary.update(inbound_count)
    self.secondary.update(outbound_count)

    self._primary_header_stats = [str(self.primary.latest_value), ', avg: %i' % self.primary.average()]
    self._secondary_header_stats = [str(self.secondary.latest_value), ', avg: %i' % self.secondary.average()]


class ResourceStats(GraphCategory):
  """
  Tracks cpu and memory usage of the tor process.
  """

  def stat_type(self):
    return GraphStat.SYSTEM_RESOURCES

  def _y_axis_label(self, value, is_primary):
    return '%i%%' % value if is_primary else str_tools.size_label(value)

  def bandwidth_event(self, event):
    resources = nyx.tracker.get_resource_tracker().get_value()
    self.primary.update(resources.cpu_sample * 100)  # decimal percentage to whole numbers
    self.secondary.update(resources.memory_bytes)

    self._primary_header_stats = ['%0.1f%%' % self.primary.latest_value, ', avg: %0.1f%%' % self.primary.average()]
    self._secondary_header_stats = [str_tools.size_label(self.secondary.latest_value, 1), ', avg: %s' % str_tools.size_label(self.secondary.average(), 1)]


class GraphPanel(nyx.panel.Panel):
  """
  Panel displaying graphical information of GraphCategory instances.
  """

  def __init__(self):
    nyx.panel.Panel.__init__(self)

    self._displayed_stat = None if CONFIG['graph_stat'] == 'none' else CONFIG['graph_stat']
    self._update_interval = CONFIG['graph_interval']
    self._bounds_type = CONFIG['graph_bound']
    self._graph_height = CONFIG['graph_height']

    self._accounting_stats = None
    self._accounting_stats_paused = None

    self._stats = {
      GraphStat.BANDWIDTH: BandwidthStats(),
      GraphStat.SYSTEM_RESOURCES: ResourceStats(),
    }

    self._stats_lock = threading.RLock()
    self._stats_paused = None

    if CONFIG['show_connections']:
      self._stats[GraphStat.CONNECTIONS] = ConnectionStats()
    elif self._displayed_stat == GraphStat.CONNECTIONS:
      log.warn("The connection graph is unavailble when you set 'show_connections false'.")
      self._displayed_stat = GraphStat.BANDWIDTH

    controller = tor_controller()
    controller.add_event_listener(self._update_accounting, EventType.BW)
    controller.add_event_listener(self._update_stats, EventType.BW)
    controller.add_status_listener(lambda *args: self.redraw())

  def stat_options(self):
    return self._stats.keys()

  def get_height(self):
    """
    Provides the height of the content.
    """

    max_height = nyx.panel.Panel.get_height(self)

    if not self._displayed_stat:
      return 0

    height = DEFAULT_CONTENT_HEIGHT + self._graph_height
    accounting_stats = self._accounting_stats if not nyx_interface().is_paused() else self._accounting_stats_paused

    if self._displayed_stat == GraphStat.BANDWIDTH and accounting_stats:
      height += 3

    return min(max_height, height)

  def set_graph_height(self, new_graph_height):
    self._graph_height = max(1, new_graph_height)

  def _resize_graph(self):
    """
    Prompts for user input to resize the graph panel. Options include...

      * down arrow - grow graph
      * up arrow - shrink graph
      * enter / space - set size
    """

    with nyx.curses.CURSES_LOCK:
      try:
        while True:
          show_message('press the down/up to resize the graph, and enter when done', BOLD)
          key = nyx.curses.key_input()

          if key.match('down'):
            # don't grow the graph if it's already consuming the whole display
            # (plus an extra line for the graph/log gap)

            max_height = nyx.curses.screen_size().height - self.get_top()
            current_height = self.get_height()

            if current_height < max_height + 1:
              self.set_graph_height(self._graph_height + 1)
          elif key.match('up'):
            self.set_graph_height(self._graph_height - 1)
          elif key.is_selection():
            break

          nyx_interface().redraw()
      finally:
        show_message()

  def set_paused(self, is_pause):
    if is_pause:
      self._accounting_stats_paused = copy.copy(self._accounting_stats)
      self._stats_paused = dict([(key, type(self._stats[key])(self._stats[key])) for key in self._stats])

  def key_handlers(self):
    def _pick_stats():
      available_stats = sorted(self.stat_options())
      options = ['None'] + [stat.capitalize() for stat in available_stats]
      previous_selection = options[available_stats.index(self._displayed_stat) + 1] if self._displayed_stat else 'None'

      selection = nyx.popups.select_from_list('Graphed Stats:', options, previous_selection)
      self._displayed_stat = None if selection == 'None' else available_stats[options.index(selection) - 1]

    def _next_bounds():
      self._bounds_type = Bounds.next(self._bounds_type)
      self.redraw()

    def _pick_interval():
      self._update_interval = nyx.popups.select_from_list('Update Interval:', list(Interval), self._update_interval)
      self.redraw()

    return (
      nyx.panel.KeyHandler('g', 'resize graph', self._resize_graph),
      nyx.panel.KeyHandler('s', 'graphed stats', _pick_stats, self._displayed_stat if self._displayed_stat else 'none'),
      nyx.panel.KeyHandler('b', 'graph bounds', _next_bounds, self._bounds_type.replace('_', ' ')),
      nyx.panel.KeyHandler('i', 'graph update interval', _pick_interval, self._update_interval),
    )

  def submenu(self):
    """
    Submenu consisting of...

      [X] <Stat 1>
      [ ] <Stat 2>
      [ ] <Stat 2>
          Resize...
          Interval (Submenu)
          Bounds (Submenu)
    """

    stat_group = RadioGroup(functools.partial(setattr, self, '_displayed_stat'), self._displayed_stat)
    interval_group = RadioGroup(functools.partial(setattr, self, '_update_interval'), self._update_interval)
    bounds_group = RadioGroup(functools.partial(setattr, self, '_bounds_type'), self._bounds_type)

    return Submenu('Graph', [
      RadioMenuItem('None', stat_group, None),
      [RadioMenuItem(str_tools._to_camel_case(opt, divider = ' '), stat_group, opt) for opt in sorted(self.stat_options())],
      MenuItem('Resize...', self._resize_graph),
      Submenu('Interval', [RadioMenuItem(opt, interval_group, opt) for opt in Interval]),
      Submenu('Bounds', [RadioMenuItem(opt, bounds_group, opt) for opt in Bounds]),
    ])

  def _draw(self, subwindow):
    if not self._displayed_stat:
      return

    if not nyx_interface().is_paused():
      stat = self._stats[self._displayed_stat]
      accounting_stats = self._accounting_stats
    else:
      if not self._stats_paused:
        return  # when first paused concurrency could mean this isn't set yet

      stat = self._stats_paused[self._displayed_stat]
      accounting_stats = self._accounting_stats_paused

    with self._stats_lock:
      subgraph_height = self._graph_height + 2  # graph rows + header + x-axis label
      subgraph_width = min(subwindow.width // 2, CONFIG['max_graph_width'])
      interval, bounds_type = self._update_interval, self._bounds_type

      subwindow.addstr(0, 0, stat.title(subwindow.width), HIGHLIGHT)

      _draw_subgraph(subwindow, stat.primary, 0, subgraph_width, subgraph_height, bounds_type, interval, PRIMARY_COLOR)
      _draw_subgraph(subwindow, stat.secondary, subgraph_width, subgraph_width, subgraph_height, bounds_type, interval, SECONDARY_COLOR)

      if stat.stat_type() == GraphStat.BANDWIDTH and accounting_stats:
        _draw_accounting_stats(subwindow, DEFAULT_CONTENT_HEIGHT + subgraph_height - 2, accounting_stats)

  def _update_accounting(self, event):
    if not CONFIG['show_accounting']:
      self._accounting_stats = None
    elif not self._accounting_stats or time.time() - self._accounting_stats.retrieved >= ACCOUNTING_RATE:
      old_accounting_stats = self._accounting_stats
      self._accounting_stats = tor_controller().get_accounting_stats(None)

      if not nyx_interface().is_paused():
        # if we either added or removed accounting info then redraw the whole
        # screen to account for resizing

        if bool(old_accounting_stats) != bool(self._accounting_stats):
          nyx_interface().redraw()

  def _update_stats(self, event):
    with self._stats_lock:
      for stat in self._stats.values():
        stat.bandwidth_event(event)

    if self._displayed_stat:
      param = self._stats[self._displayed_stat]
      update_rate = INTERVAL_SECONDS[self._update_interval]

      if param.primary.tick % update_rate == 0:
        self.redraw()


def _draw_subgraph(subwindow, data, x, width, height, bounds_type, interval, color, fill_char = ' '):
  """
  Renders subgraph including its title, labeled axis, and content.
  """

  columns = width - 8  # y-axis labels can be at most six characters wide with a space on either side
  min_bound, max_bound = data.bounds(bounds_type, interval, columns)

  x_axis_labels = _x_axis_labels(interval, columns)
  y_axis_labels = _y_axis_labels(height, data, min_bound, max_bound)

  x_axis_offset = max([len(label) for label in y_axis_labels.values()])
  columns = max(columns, width - x_axis_offset - 2)

  subwindow.addstr(x, 1, data.header(width), color, BOLD)

  for x_offset, label in x_axis_labels.items():
    subwindow.addstr(x + x_offset + x_axis_offset, height, label, color)

  for y, label in y_axis_labels.items():
    subwindow.addstr(x, y, label, color)

  for col in range(columns):
    column_count = int(data.values[interval][col]) - min_bound
    column_height = int(min(height - 2, (height - 2) * column_count / (max(1, max_bound) - min_bound)))
    subwindow.vline(x + col + x_axis_offset + 1, height - column_height, column_height, color, HIGHLIGHT, char = fill_char)


def _x_axis_labels(interval, columns):
  """
  Provides the labels for the x-axis. We include the units for only its first
  value, then bump the precision for subsequent units. For example...

    10s, 20, 30, 40, 50, 1m, 1.1, 1.3, 1.5
  """

  x_axis_labels = {}

  interval_sec = INTERVAL_SECONDS[interval]
  interval_spacing = 10 if columns >= WIDE_LABELING_GRAPH_COL else 5
  previous_units, decimal_precision = None, 0

  for i in range((columns - 4) // interval_spacing):
    x = (i + 1) * interval_spacing
    time_label = str_tools.time_label(x * interval_sec, decimal_precision)

    if not previous_units:
      previous_units = time_label[-1]
    elif previous_units != time_label[-1]:
      previous_units = time_label[-1]
      decimal_precision = 1  # raised precision for future measurements
    else:
      time_label = time_label[:-1]  # strip units since already provided

    x_axis_labels[x] = time_label

  return x_axis_labels


def _y_axis_labels(subgraph_height, data, min_bound, max_bound):
  """
  Provides the labels for the y-axis. This is a mapping of the position it
  should be drawn at to its text.
  """

  y_axis_labels = {
    2: data.y_axis_label(max_bound),
    subgraph_height - 1: data.y_axis_label(min_bound),
  }

  ticks = (subgraph_height - 5) // 2

  for i in range(ticks):
    row = subgraph_height - (2 * i) - 5

    if subgraph_height % 2 == 0 and i >= (ticks // 2):
      row -= 1  # make extra gap be in the middle when we're an even size

    val = (max_bound - min_bound) * (subgraph_height - row - 3) // (subgraph_height - 3)

    if val not in (min_bound, max_bound):
      y_axis_labels[row + 2] = data.y_axis_label(val)

  return y_axis_labels


def _draw_accounting_stats(subwindow, y, accounting):
  if tor_controller().is_alive():
    hibernate_color = CONFIG['attr.hibernate_color'].get(accounting.status, RED)

    x = subwindow.addstr(0, y, 'Accounting (', BOLD)
    x = subwindow.addstr(x, y, accounting.status, BOLD, hibernate_color)
    x = subwindow.addstr(x, y, ')', BOLD)

    subwindow.addstr(35, y, 'Time to reset: %s' % str_tools.short_time_label(accounting.time_until_reset))

    subwindow.addstr(2, y + 1, '%s / %s' % (_size_label(accounting.read_bytes), _size_label(accounting.read_limit)), PRIMARY_COLOR)
    subwindow.addstr(37, y + 1, '%s / %s' % (_size_label(accounting.written_bytes), _size_label(accounting.write_limit)), SECONDARY_COLOR)
  else:
    subwindow.addstr(0, y, 'Accounting:', BOLD)
    subwindow.addstr(12, y, 'Connection Closed...')


def _size_label(byte_count, decimal = 1):
  """
  Alias for str_tools.size_label() that accounts for if the user prefers bits
  or bytes.
  """

  return str_tools.size_label(byte_count, decimal, is_bytes = not CONFIG['show_bits'], round = True)
