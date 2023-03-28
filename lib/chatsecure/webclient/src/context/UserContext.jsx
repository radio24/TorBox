import { createContext, useState } from "react";

export const UserContext = createContext();

export const UserProvider = (props) => {
  const [privKey, setPrivKey] = useState(null)
  const [pubKey, setPubKey] = useState(null)
  const [pubKeyFp, setPubKeyFp] = useState("")
  const [userId, setUserId] = useState(null)
  // const [userList, setUserList] = useState([{
  //   name: '',
  //   pubkey: '',
  //   fp: '',
  //   last_update: '',
  // }])
  const [messages, setMessages] = useState([])
  const [token, setToken] = useState(null)


  return (
    <UserContext.Provider
      value={{
        privKey, setPrivKey,
        pubKey, setPubKey,
        pubKeyFp, setPubKeyFp,
        userId, setUserId,
        // userList, setUserList,
        messages, setMessages,
        token, setToken,
      }}
    >
      {props.children}
    </UserContext.Provider>
  );
};
