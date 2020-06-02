#!/usr/bin/python3

tmp_dir = '/tmp' # where we store the temporal captchas to solve (full path)
tor_get_bridges_url = 'https://bridges.torproject.org/bridges?transport=obfs4' # url where we get the bridges

# -

from PIL import Image, ImageFilter
from pytesseract import image_to_string
from mechanize import Browser

import re
import os
import base64

bridges = False
while bridges == False:
	# open page first
	br = Browser()
	br.set_handle_robots(False)
	res = br.open(tor_get_bridges_url)

	# look for the captcha image
	html = str(res.read()) 
	q = re.findall(r'src="data:image/jpeg;base64,(.*?)"', html, re.DOTALL)
	img_data = q[0]

	# store captcha image
	f = open('%s/captcha.jpg' % tmp_dir, 'wb')
	f.write( base64.b64decode(img_data) )
	f.close()

	# cleaning captcha
	os.system('convert %s/captcha.jpg -threshold 15%% %s/captcha.tif'  % (tmp_dir, tmp_dir))
	os.system('convert %s/captcha.tif -morphology Erode Disk:2 %s/captcha.tif'  % (tmp_dir, tmp_dir))

	# solve the captcha
	captcha_text =  image_to_string(Image.open('%s/captcha.tif' % tmp_dir), config='-c tessedit_char_whitelist=0123456789ABCDEFGHIJKMNLOPKRSTUVWXYZabcdefghijklmnopqrstuvwxyz')

	# if captcha len doesn't match on what we look, we just try again
	if len(captcha_text) < 7 or len(captcha_text) > 7:
		continue
	
	# reply to server with the captcha text
	br.select_form(nr=0)
	br['captcha_response_field'] = captcha_text
	reply = br.submit()

	# look for the bridges if the captcha was beaten
	html = str(reply.read())
	q = re.findall(r'<div class="bridge-lines" id="bridgelines">(.*?)</div>', html, re.DOTALL)
	try:
		txt = q[0]
		b = txt.split('<br />')
		r = []
		for l in b:
			_b = l.strip().replace('\\n', '')
			if _b != '':
				bridges = _b
	# captcha failed, try again
	except Exception as e:
		pass

print(bridges)
