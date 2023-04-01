import {createContext, useContext, useEffect, useState} from "react";
import {io} from "socket.io-client";
import {UserContext} from "./UserContext.jsx";
import {APIClient} from "../hooks/APIClient.jsx";

let socket;

export const ChatContext = createContext();

export const ChatProvider = (props) => {
  const {
    privKey, pubKey, pubKeyFp, token, userId
  } = useContext(UserContext)

  const [userList, setUserList] = useState([])
  const [chatName, setChatName] = useState("Default")
  const [chatId, setChatId] = useState("default")  // Default group
  const [chatGroup, setChatGroup] = useState(true)  // Start showing group
  const [chatMessages, setChatMessages] = useState([])

  // const URL = process.env.NODE_ENV === 'production' ? undefined : 'http://localhost:5000';
  const URL = 'http://127.0.0.1:5000';
	const api = APIClient(token)

  // let socket = io(URL, {auth: {token: token}})

  const sendMessage = (msg) => {
    const data = {
      sender: userId,
      recipient: chatId,
      msg: msg,
      is_group: chatGroup,
    }
    console.log("send msg: ", data)
    socket.emit("msg", data)

    data.id = new Date().getTime()
    setChatMessages([...chatMessages, data])
  }

	function onMessage(value) {
		if (value.sender !== userId) {
			console.log(chatMessages)
			console.log("onMessage: ", value)
			setChatMessages([...chatMessages, value])
		}
	}

	function onNewUser(value) {
			const v = JSON.parse(value)
			if (v.id !== userId) {
				console.log(userList)
				console.log("new_user: ", v)
				setUserList([...userList, value])
			}
    }

		useEffect(() => {
			if (chatMessages.length) {
				socket.on('new_user', onNewUser);
			}
		}, [chatMessages])

  useEffect(() => {
    if (token !== null && token !== "") {
			socket = io(URL, {auth: {token: token}})
      socket.connect();

			// api.getUserList().then(r => { setUserList(r); })
    }
    function onConnect() {
      console.log("Socketio connected")
    }
    //
    function onDisconnect() {
      console.log("Socketio ** DISCONNECT **")
    }


    socket.on('connect', onConnect);
    socket.on('disconnect', onDisconnect);
    socket.on('message', onMessage);
    socket.on('new_user', onNewUser);

    return () => {
      socket.off('connect', onConnect);
      socket.off('disconnect', onDisconnect);
      socket.off('message', onMessage);
      socket.off('new_user', onNewUser);
    };
  }, [token])


  return (
    <ChatContext.Provider
      value={{
        userList, setUserList,
        chatName, setChatName,
        chatId, setChatId,
        chatGroup, setChatGroup,
        chatMessages, setChatMessages,
        sendMessage
      }}
    >
      {props.children}
    </ChatContext.Provider>
  );
};
