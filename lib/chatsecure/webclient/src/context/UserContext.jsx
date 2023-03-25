import { createContext, useState } from "react";
import { Outlet } from "react-router-dom";

export const UserContext = createContext();

export const UserProvider = (props) => {
  const [privKey, setPrivKey] = useState(null)
  const [pubKey, setPubKey] = useState(null)
  const [pubKeyFp, setPubKeyFp] = useState("")
  const [userList, setUserList] = useState([{
    name: '',
    pubkey: '',
    fp: '',
    img: '',
    last_ts: '',
  }])
  const [messages, setMessages] = useState([])
  const [selectedChat, setSelectedChat] = useState(null)
  const [token, setToken] = useState(null)


  return (
    <UserContext.Provider
      value={{
        privKey, setPrivKey,
        pubKey, setPubKey,
        pubKeyFp, setPubKeyFp,
        userList, setUserList,
        messages, setMessages,
        selectedChat, setSelectedChat,
        token, setToken,
      }}
    >
      {props.children}
      <Outlet />
    </UserContext.Provider>
  );
};
