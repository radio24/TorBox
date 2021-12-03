//-------------------------------
// TorBox Chat Secure
//-------------------------------

import './nacl-fast.js';
import './nacl-util.js';
import './socket.io.js';
import { get_csrftoken } from './csrftoken.js';

var nick = '';

// Keys
var pub_key = String();
var sec_key = String();

// db object
const db_name = "torbox-chat-secure";
const indexed_db = window.indexedDB;
var db_request;
var db;

var chat_active_nick;
var socket;

// id shortener function
const $id = selector => document.getElementById(selector)

// Key generator
async function generate_keys() {
    const key_pair = nacl.box.keyPair();
    sec_key = key_pair.secretKey;
    pub_key = key_pair.publicKey;
}
async function socket_setup() {
    socket = io.connect();

    // Connect to socket
    socket.on('connect', () => {
        socket.emit('auth', {
            nick: nick,
            pub_key: nacl.util.encodeBase64(pub_key)
        });
    })

    // Msg incoming
    socket.on('message', (e) => {
        // get message and notify
        const user_nick = e.nick;
        const msg_enc = new Uint8Array(e.message.encrypted);
        const nonce = new Uint8Array(e.message.nonce);

        // Load pub_key
        const tx = db.transaction("users");
        const store = tx.objectStore("users");
        const request = store.get(user_nick);
        request.onsuccess = () => {
            const r = request.result;
            const user_pub_key = r.pub_key;

            // decrypt msg
            const msg_dec = nacl.box.open(
                msg_enc,
                nonce,
                nacl.util.decodeBase64(user_pub_key),
                sec_key
            );
            const msg = nacl.util.encodeUTF8(msg_dec);

            // Add msg to local db
            const tx = db.transaction("messages", "readwrite")
                .objectStore("messages")
                .add({nick: user_nick, message: msg, in: true});
            
            // Render if it's active
            if (chat_active_nick == user_nick) {
                chat_render_msg(msg, true);
            }
            else {
                // Notify
                const user_node = document
                    .querySelector(`#torbox-user-list [data-nick='${user_nick}']`);
                
                // Only if not already notified
                if (user_node.querySelector('.torbox-notification') == null)
                {
                    const notification_icon = document.createElement('i');
                    notification_icon.classList.add("torbox-notification");
                    notification_icon.classList.add("fas");
                    notification_icon.classList.add("fa-envelope");
                    notification_icon.classList.add("has-text-danger");
                    notification_icon.classList.add("is-pulled-right");
                    user_node.appendChild(notification_icon)
                }

                // Move user up
                $id('torbox-user-list').prepend(user_node.parentNode);
            }
        }
    })

    // New user connected
    socket.on('user-connected', (e) => {
        // add user to list
        chat_render_user_list(e.nick, e.pub_key);
    })
}
async function socket_send_msg(user_nick, msg) {
    // Load pub_key
    const tx = db.transaction("users");
    const store = tx.objectStore("users");
    const request = store.get(user_nick);
    request.onsuccess = () => {
        const r = request.result;
        const user_pub_key = r.pub_key;

        // Encrypt msg
        const nonce = nacl.randomBytes(24);
        const encrypted = nacl.box(
            nacl.util.decodeUTF8(msg),
            nonce,
            nacl.util.decodeBase64(user_pub_key),
            sec_key
        );

        const msg_enc = {encrypted,nonce};
        socket.emit('message', {nick: user_nick, message: msg_enc});
    }

}
async function chat_setup() {
    chat_load_user_list()

    // Event: send msg when pressing enter
    $id('message').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') chat_send_msg();
    });
    $id('message_btn').addEventListener('click', chat_send_msg);

    // Remove modal
    $id('torbox-init').classList.remove('is-active');
    // Show content
    $id('torbox-header').classList.remove('is-hidden');
    $id('torbox-admin-msg').classList.remove('is-hidden');
    $id('torbox-content').classList.remove('is-hidden');
    // Set nick at title
    $id('torbox-title-nick').innerText = nick;
}
async function check_nick_available(nick) {
    let reply = false;
    await fetch('/nick_available/', {
        method: 'POST',
        body: JSON.stringify({nick: nick}),
        headers: {
            'X-CSRFToken': get_csrftoken(),
            'Content-Type': 'application/json'
        }
    })
    .then(response => response.json())
    .then(res => {
        reply = res['reply'];
    });
    return reply;
}
// Connect to chat with nick and pub key
async function chat_connect() {
    let reply = false;
    await fetch('/user_connect/', {
        method: 'POST',
        body: JSON.stringify({
            nick: nick,
            pub_key: nacl.util.encodeBase64(pub_key)}),
        headers: {
            'X-CSRFToken': get_csrftoken(),
            'Content-Type': 'application/json'
        }
    })
    .then(response => response.json())
    .then(res => {
        reply = res['reply'];

        if (reply) {
            socket_setup();
        }
    });
    return reply;
}
async function chat_load_user_list() {
    let users = []
    await fetch('/user_list/', {
        method: 'GET',
        headers: {
            'X-CSRFToken': get_csrftoken(),
            'Content-Type': 'application/json'
        }
    })
    .then(response => response.json())
    .then(users => {
        users.forEach((user) => {
            chat_render_user_list(user.nick, user.pub_key);
        })
    })
}
async function chat_render_user_list(user_nick, user_pub_key) {
    if (user_nick == nick) return;

    const tx = db.transaction("users");
    const store = tx.objectStore("users");
    const request = store.get(user_nick);
    request.onsuccess = () => {
        if (!request.result) {
            // Store users in local db
            const tx = db.transaction("users", "readwrite")
                .objectStore("users")
                .add({nick: user_nick, pub_key: user_pub_key});
        
            // Create user in list
            const li = document.createElement('li');
            const a = document.createElement('a');
            a.dataset.nick = user_nick;
            a.addEventListener('click', chat_load_msgs);
            a.innerHTML = `<i class="fas fa-user"></i> ${user_nick} `;
            li.appendChild(a)
            $id('torbox-user-list').appendChild(li);
        }
    }
}
async function chat_load_msgs(e) {
    // Nick of selected user
    const user_nick = e.target.dataset.nick;

    // Enable message input
    $id('message').disabled = false;
    $id('message_btn').disabled = false;
    $id('message').focus();

    // Select user in user-list
    document.querySelectorAll("#torbox-user-list a")
        .forEach(obj => obj.classList.remove('is-active'));
    e.target.classList.add('is-active');
    // Remove notification if any
    const notification = e.target.querySelector(".torbox-notification");
    if (notification) {
        e.target.removeChild(notification);
    }

    chat_active_nick = user_nick;
    chat_render_all_msgs(user_nick);
}
async function chat_render_all_msgs(user_nick) {
    // Clear displayed msgs
    document.querySelector('#torbox-messages .msg-wrapper').innerHTML = '';

    // Load msgs from db
    const tx = db.transaction("messages");
    const store = tx.objectStore("messages");
    const cursor_request = store.openCursor();
    cursor_request.onsuccess = (e) => {
        const cursor = e.target.result;
        if (cursor) {
            if (cursor.value.nick == chat_active_nick) {
                const msg = cursor.value
                chat_render_msg(msg.message, msg.in);
            }
            cursor.continue();
        }
    }
}
async function chat_render_msg(msg, incoming=false) {
    // Message text
    const msg_text = document.createElement('div');
    msg_text.classList.add('box');
    if (incoming) msg_text.classList.add('in');
    //msg_text.innerHTML = msg;
    msg_text.innerText = msg;

    // Message container
    const msg_html = document.createElement('div')
    msg_html.classList.add('msg');
    msg_html.appendChild(msg_text);
    
    // Add message to div and manage scrollbar
    const msgs = $id('torbox-messages');

    // Manage scrollbar
    let scroll_down = false;
    const scroll_now = msgs.offsetHeight + msgs.scrollTop;
    if (msgs.scrollHeight == scroll_now) {
        scroll_down = true;
    }

    // add msg
    msgs.querySelector('.msg-wrapper').appendChild(msg_html)

    // Scroll down if needed
    if (scroll_down) {
        msgs.scrollTo(0, msgs.scrollHeight);
    }

}
async function chat_send_msg() {
    if ($id('message').value == '') return;

    const msg = $id('message').value;
    $id('message').value = '';

    socket_send_msg(chat_active_nick, msg);

    // Add msg to local db
    const tx = db.transaction("messages", "readwrite")
        .objectStore("messages")
        .add({nick: chat_active_nick, message: msg, in: false});
    
    chat_render_msg(msg);
}
async function nick_txt_validate(e) {
    const key_code = e.keyCode || e.which;
    // if enter pressed, try to start
    if (key_code == 13)
        if ($id('nick_txt').value.length)
        {
            $id('start_btn').focus();
            $id('start_btn').click();
        }

    // alphanumeric nick
    const pattern = /^[a-z0-9_]+$/i;
    e.returnValue = pattern.test(String.fromCharCode(key_code));
    //e.target.value = e.target.value.replace(/[^\w]+/g, '');
}
// Start
async function start(e) {
    const nick_txt = $id('nick_txt');
    const start_btn = e.target;

    if (nick_txt.value.length) {
        $id('nick_error').classList.add('is-hidden');
        nick_txt.classList.remove('is-danger');
        nick_txt.disabled = true;
        start_btn.classList.add('is-loading');
        
        const nick_available = await check_nick_available(nick_txt.value);
        if (nick_available) {
            nick = nick_txt.value;
            generate_keys();  // Generate pub/sec keys

            const connected = chat_connect();
            if (connected) {
                chat_setup();
            }
            else {
                // Alert can't connect
            }
            
        }
        else {
            // alert nick not available
            nick_txt.classList.add('is-danger');
            nick_txt.disabled = false;
            start_btn.classList.remove('is-loading');
            $id('nick_error').innerHTML = 'Nickname not available';
            $id('nick_error').classList.remove('is-hidden');
        }
        
    }
    else {
        // Nick is empty
        nick_txt.classList.add('is-danger')
        $id('nick_error').innerHTML = 'Enter a nickname';
        $id('nick_error').classList.remove('is-hidden');
    }

}

// Clean local DB at start
async function db_clean() {
    const idb = indexed_db.deleteDatabase(db_name)
    // idb.onsuccess = () => console.log("deleted db");
    // idb.onerror = () => console.log("db doesn't exist");
    // idb.onblocked = () => console.log("blocked!");

    // Setup local db
    db_request = indexed_db.open(db_name, 1);

    db_request.onupgradeneeded = () => {
        db = db_request.result;
        db.createObjectStore("users", {keyPath: "nick"});
        const store = db.createObjectStore("messages",
                                           {keyPath: "id", autoIncrement: true});
        store.createIndex("nick", "nick", {unique: false});

    }
}

//------------
// Main
//------------
export function main() {
    db_clean();

    // Add event listeners
    $id('start_btn').addEventListener('click', start);
    $id('nick_txt').addEventListener('keyup', (e) => {
        $id('nick_error').classList.add('is-hidden');
        $id('nick_txt').classList.remove('is-danger');
    });
    $id('nick_txt').addEventListener('keypress', nick_txt_validate);
}


