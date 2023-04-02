import avatarDemo from "../../assets/avatar.png";
import "./ContactList.css"
import Sha256 from "crypto-js/sha256.js";
import {Identicon} from "@polkadot/react-identicon";
import {useContext} from "react";
import {ChatContext} from "../../context/ChatContext.jsx";

export const ContactList = props => {
  const {
    userList,
    chatId, selectChat,
    chatName } = useContext(ChatContext)
  const { setVisible } = props

	const UserContact = props => {
		const { chat } = props
		return (
			<div
				// key={chat.id}
				className={'grid grid-cols-[55px_1fr] py-3 pl-8 pr-10 border-b border-slate-600 hover:bg-slate-600 cursor-pointer ' + (chatId===chat.id?" bg-slate-500":"")}
				onClick={e => { selectChat(chat.id) }}
			>
				<div className='w-full'>
					<div className={"flex w-full h-full object-cover rounded-full bg-slate-600"}>
						<Identicon className={"m-auto"} size={40} value={String("0x" + Sha256(chat.fp)) } theme={"substrate"} />
					</div>
				</div>
				<div className='w-full ml-5'>
					<span className={"text-lg text-slate-300"}>{chat.name}</span>
					<span className={"text-base text-slate-400 font-light line-clamp-1"}>chat.message</span>
				</div>
			</div>
		)
	}

  return (
    <div className='flex flex-col w-full h-full overflow-auto
    bg-slate-700 p-0
    '>
      <div className='flex'
        onClick={e => { setVisible(false) }}>
        <span className='text-2xl text-lime-500 pl-8 pt-5 pb-2'>Chats</span>
      </div>
      <div
        className={'grid grid-cols-[55px_1fr] py-3 pl-8 pr-10 border-b border-slate-600 hover:bg-slate-600 cursor-pointer ' + (chatId==="default"?" bg-slate-500":"")}
        onClick={e => { selectChat("default") }}
      >
        <div className='w-full'>
          <div className={"flex w-full h-full object-cover rounded-full bg-lime-500"}>
            &nbsp;
          </div>
        </div>
        <div className='w-full ml-5'>
          <span className={"text-lg text-slate-300"}>{chatName} Group</span>
          <span className={"text-base text-slate-400 font-light line-clamp-1"}>chat.message</span>
        </div>
      </div>
      {
        userList.map((chat) => (
          <UserContact key={chat.id} chat={chat} />
        ))
      }
    </div>
  )
}
