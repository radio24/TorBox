import {createContext, useContext, useEffect, useRef, useState} from "react";
import {io} from "socket.io-client";
import {UserContext} from "./UserContext.jsx";
import {APIClient} from "../hooks/APIClient.jsx";
import { config } from "../utils/constants"

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

	const chatIdRef = useRef(chatId)
	const chatMessagesRef = useRef(chatMessages)
	const userListRef = useRef(userList)

	const api = APIClient(token)

  const sendMessage = (msg) => {
    const data = {
      sender: userId,
      recipient: chatId,
      msg: msg,
      is_group: chatGroup,
    }
    socket.emit("msg", data)

    data.id = new Date().getTime()
    setChatMessages([...chatMessages, data])
  }

	function selectChat(id) {
		console.log("setChatId(): ", id)
		setChatId(id)
	}

	function onMessage(value) {
		if (value.sender !== userId) {
			console.log("onMessage: ", value)
			console.log("chatId: ", chatIdRef.current)
			if (chatIdRef.current === "default" && value.recipient === "default") {
				setChatMessages([...chatMessagesRef.current, value])
			}
			if (chatIdRef.current !== "default" && value.sender === chatIdRef.current && value.recipient === userId) {
				setChatMessages([...chatMessagesRef.current, value])
			}
		}
	}

	function onUserConnected(value) {
		const v = JSON.parse(value)
		if (v.id !== userId) {
			setUserList([...userListRef.current, v])
		}
	}

	function onUserDisconnected () {}

	const initSocket = () => {
		socket = io(config.url.API_URL, {auth: {token: token}})
		socket.connect()
		initSocketEvents()
	}
	const initSocketEvents = () => {
		// socket.on('connect', onConnect)
		// socket.on('disconnect', onDisconnect)
		socket.on('message', onMessage)
		socket.on('user_connected', onUserConnected)
	}

  useEffect(() => {
    if (token !== null && token !== "") {
			initSocket()
    }
  }, [token])

	useEffect(() => {
		// console.log("ChatID CHANGED TO: ",chatId)
		chatIdRef.current = chatId
	}, [chatId])

	useEffect(() => {
		chatMessagesRef.current = chatMessages
	}, [chatMessages])

	useEffect(() => {
		userListRef.current = userList
	}, [userList])

  return (
    <ChatContext.Provider
      value={{
        userList, setUserList,
        chatName, setChatName,
        chatId, setChatId,
        chatGroup, setChatGroup,
        chatMessages, setChatMessages,
        sendMessage, selectChat
      }}
    >
      {props.children}
    </ChatContext.Provider>
  );
};
