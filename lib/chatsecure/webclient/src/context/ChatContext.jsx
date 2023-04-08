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

	const [loading, setLoading] = useState(true)
  const [userList, setUserList] = useState([])
  const [chatName, setChatName] = useState("Default")
  const [chatId, setChatId] = useState("default")  // Default group
  const [chatGroup, setChatGroup] = useState(true)  // Start showing group
  const [chatMessages, setChatMessages] = useState([])

	const chatIdRef = useRef(chatId)
	const chatMessagesRef = useRef(chatMessages)
	const userListRef = useRef(userList)

	const api = APIClient(token)

	const getUserInfo = id => {
		return userListRef.current.filter(obj => obj.id === id)[0]
	}

	const updateUserList = ul => {
		setUserList(ul.sort((a, b) => {
			return Number(b.active) - Number(a.active)
		}))
	}

	function selectChat(id) {
		if (id === "default") {
			// group
			setChatGroup(true)
			setChatName("Group")
		}
		else {
			// user
			setChatGroup(false)
			const user = getUserInfo(id)
			setChatName(user.name)
		}
		setChatId(id)
	}

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

	function onMessage(value) {
		if (value.sender !== userId) {
			if (chatIdRef.current === "default" && value.recipient === "default") {
				setChatMessages([...chatMessagesRef.current, value])
			}
			if (chatIdRef.current !== "default" && value.sender === chatIdRef.current && value.recipient === userId) {
				setChatMessages([...chatMessagesRef.current, value])
			}
		}
	}

	function onUserConnected(data) {
		if (data.id !== userId) {
			// Check if user is already added
			const contactOnList = userListRef.current.find(obj => obj.id === data.id)
			console.log("contact exists?:", contactOnList)
			if (contactOnList) {
				console.log("YASS add:", data)
				updateUserList([...userListRef.current.filter(obj => obj.id !== data.id), data])
			}
			else {
				updateUserList([...userListRef.current, data])
			}

		}
	}

	function onUserDisconnected (data) {
		updateUserList(
			userListRef.current.map(obj => {
				if (obj.id === data.id) {
					obj.active = false
				}
				return obj
			})
		)
	}

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
		socket.on('user_disconnected', onUserDisconnected)
	}

	const initData = async () => {
    // await api.getGroupList().then(r => { console.log(r) })
    await api.getUserList().then(r => { updateUserList(r); })
    await api.getGroupMessageList().then(r => { setChatMessages(r) })
    setLoading(false)
  }

  useEffect(() => {
    if (token !== null && token !== "") {
			initSocket()
			initData()
    }
  }, [token])

	useEffect(() => {
		chatIdRef.current = chatId

		if (chatId !== "default") {
      api.getUserMessageList(chatId).then(r => { setChatMessages(r) } )
    }
    else {
      api.getGroupMessageList().then(r => { setChatMessages(r) })
    }
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
				loading, setLoading,
        userList, setUserList, updateUserList, getUserInfo,
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
