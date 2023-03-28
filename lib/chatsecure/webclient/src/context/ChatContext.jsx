import { createContext, useState } from "react";

export const ChatContext = createContext();

export const ChatProvider = (props) => {
  const [userList, setUserList] = useState([])
  const [chatName, setChatName] = useState("Default")
  const [chatId, setChatId] = useState(1)  // Default group
  const [chatGroup, setChatGroup] = useState(true)  // Start showing group
  const [chatMessages, setChatMessages] = useState([])


  return (
    <ChatContext.Provider
      value={{
        userList, setUserList,
        chatName, setChatName,
        chatId, setChatId,
        chatGroup, setChatGroup,
        chatMessages, setChatMessages,
      }}
    >
      {props.children}
    </ChatContext.Provider>
  );
};
