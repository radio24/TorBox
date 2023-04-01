import {createContext, useContext, useEffect, useState} from "react";
import {io} from "socket.io-client";
import {UserContext} from "./UserContext.jsx";

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
  let socket = io(URL, {auth: {token: token}});

  // const initSocket = () => {
  //   socket = io(URL, {auth: {token: token}});
  //
  // }

  useEffect(() => {
    if (token !== null && token !== "") {
      // initSocket()
      console.log("socket connect")
      socket.connect();
      console.log("--- GO ---")
    }
    // function onConnect() {
    //   console.log("Socketio connected")
    //   // setIsConnected(true);
    // }
    //
    // function onDisconnect() {
    //   console.log("Socketio ** DISCONNECT **")
    //   // setIsConnected(false);
    // }

    function onMessage(value) {
      console.log("onMessage!: ", value)
    }

    function onNewUser(value) {
      console.log("onNewUser: ", value)
    }

    // socket.on('connect', onConnect);
    // socket.on('disconnect', onDisconnect);
    socket.on('message', onMessage);
    socket.on('new_user', onNewUser);

    return () => {
      // socket.off('connect', onConnect);
      // socket.off('disconnect', onDisconnect);
      socket.off('message', onMessage);
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
        socket
      }}
    >
      {props.children}
    </ChatContext.Provider>
  );
};
