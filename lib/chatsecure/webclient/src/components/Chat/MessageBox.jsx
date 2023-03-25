import {InputTextarea} from "primereact/inputtextarea";
import {Button} from "primereact/button";
import {BsEmojiLaughing, BsSendFill} from "react-icons/all.js";
import data from '@emoji-mart/data'
import Picker from '@emoji-mart/react'
import {useState} from "react";
import "./MessageBox.css"
import {Card} from "primereact/card";
import avatarDemo from "../../assets/avatar.png"
import {MessageIn} from "./MessageIn.jsx";
import {MessageOut} from "./MessageOut.jsx";

export const MessageBox = props => {

  const {
    socket,
    userId,
    chatId,
    chatGroup,
    chatMessages, setChatMessages,
  } = props

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

    data.key = new Date().getTime()
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
          <div className={"absolute sm:py-8 py-5 bottom-0 overflow-auto flex flex-col w-full max-h-full space-y-3"}>
            {chatMessages.map(m => {
              if (m.sender_id == userId) {
                return (
                  <MessageOut key={m.key} text={m.msg} />
                )
              }
              else {
                return(
                  <MessageIn key={m.key} text={m.msg} />
                )
              }
            })
            }
            {/*<MessageIn text={"Hi"} />*/}
            {/*<MessageOut text={"Hi, how are you?"} />*/}
            {/*<MessageIn text={"Lorem ipsum dolor sit amet, consectetur adipisicing elit. Et, possimus?"} />*/}
            {/*<MessageOut text={"Lorem ipsum dolor sit amet, consectetur adipisicing elit. Et, possimus?"} />*/}
            {/*<MessageIn text={"Lorem ipsum dolor sit amet, consectetur adipisicing elit. Debitis dicta iste laborum officiis placeat quos. Alias aliquid autem dolore dolores doloribus eaque est explicabo hic, inventore iure libero magnam magni minima molestiae nihil officiis optio, perspiciatis repellat reprehenderit repudiandae saepe sit sunt totam ullam ut vitae voluptatibus? Eligendi, esse non."} />*/}
            {/*<MessageOut text={"Lorem ipsum dolor sit amet, consectetur adipisicing elit. Et, possimus?"} />*/}
            {/*<MessageIn text={"Lorem ipsum dolor sit amet, consectetur adipisicing elit. Et, possimus?"} />*/}
            {/*<MessageOut text={"Lorem ipsum dolor sit amet, consectetur adipisicing elit. Debitis dicta iste laborum officiis placeat quos. Alias aliquid autem dolore dolores doloribus eaque est explicabo hic, inventore iure libero magnam magni minima molestiae nihil officiis optio, perspiciatis repellat reprehenderit repudiandae saepe sit sunt totam ullam ut vitae voluptatibus? Eligendi, esse non."} />*/}
            {/*<MessageIn text={"Lorem ipsum dolor sit amet, consectetur adipisicing elit. Et, possimus?"} />*/}

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