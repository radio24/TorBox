import {InputTextarea} from "primereact/inputtextarea";
import {Button} from "primereact/button";
import {BsEmojiLaughing, BsSendFill} from "react-icons/all.js";
import data from '@emoji-mart/data'
import Picker from '@emoji-mart/react'
import {useContext, useState} from "react";
import "./MessageBox.css"
import {Card} from "primereact/card";
import avatarDemo from "../../assets/avatar.png"
import {MessageIn} from "./MessageIn.jsx";
import {MessageOut} from "./MessageOut.jsx";
import {UserContext} from "../../context/UserContext.jsx";
import {ChatContext} from "../../context/ChatContext.jsx";

export const MessageBox = props => {

  const {
    pubKeyFp,
    userId
  } = useContext(UserContext)

  const {
    chatId, chatGroup,
    chatMessages, setChatMessages,
    socket,
  } = useContext(ChatContext)

  const [message, setMessage] = useState("")
  const [showEmoji, setShowEmoji] = useState(false)

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
    setMessage("")
  }

  const onMessageKeyDown = async (e) => {
    if (e.keyCode == 13 && e.shiftKey == false) {
      // Send message
      e.preventDefault();
      sendMessage(message)
    }
    else {
      setMessage(e.target.value)
    }
  }

  return(
    <div className='flex flex-col w-full h-full
    bg-slate-600/80'>

      {/*messages*/}
      <div className={"relative flex w-full h-[calc(100%-50px)]"} style={{overflow: "none"}}>
          <div onClick={() => { }} className={"absolute sm:py-8 py-5 bottom-0 overflow-auto flex flex-col w-full max-h-full space-y-3"}>
            {chatMessages.map(m => {
              if (m.sender === userId) {
                return (
                  <MessageOut key={m.id} text={m.msg} messageData={m} />
                )
              }
              else {
                return(
                  <MessageIn key={m.id} text={m.msg} messageData={m} />
                )
              }
            })
            }
          </div>
      </div>

      {/*input*/}
      <div className={"relative flex flex-col w-full bg-white"}>
        <div className={"flex min-h-[50px] max-h-[50px]"}>
          <InputTextarea
            autoResize
            rows={2}
            className={"msg-input flex-grow my-1"}
            placeholder={"Write a message..."}
            value={message}
            onChange={e => { setMessage(e.target.value) }}
            onKeyDown={onMessageKeyDown}
          />
          <div className={"flex"}>
            {/*FOR DESKTOP ONLY*/}
            <Button
              className={"emoji-button hidden lg:flex my-auto p-button-text"}
              id={"emoji-button"}
              icon={<BsEmojiLaughing size={"25"} />}
              onClick={(e) => { setShowEmoji(!showEmoji) }}
            />
            <Button className={"my-auto mr-2 p-button-rounded"} icon={<BsSendFill />} disabled={(!message.length)} />
          </div>
        </div>
      </div>

      {showEmoji &&
        <div className={"absolute bottom-[95px] right-[45px] flex"}>
          <Picker
            className={"w-[300px]"}
            data={data}
            onEmojiSelect={e => { setMessage(message + e.native)  }}
            perLine={9}
            searchPosition={"none"}
            previewPosition={"none"}
            maxFrequentRows={0}
            onClickOutside={(e) => { if (e.target.id != "emoji-button") setShowEmoji(false) }}
          />
        </div>
      }
    </div>
  )
}