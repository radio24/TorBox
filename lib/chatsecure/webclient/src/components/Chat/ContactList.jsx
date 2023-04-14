import avatarDemo from "../../assets/avatar.png";
import "./ContactList.css"
import Sha256 from "crypto-js/sha256.js";
import {Identicon} from "@polkadot/react-identicon";
import {useContext, useEffect, useState} from "react";
import {ChatContext} from "../../context/ChatContext.jsx";
import {
	BsCircleFill,
	CgLogOff,
	MdLogout,
	RiSettings4Line
} from "react-icons/all.js";
import {UserContext} from "../../context/UserContext.jsx";

export const ContactList = props => {
	const {
		pubKeyFp, userName, logout
	} = useContext(UserContext)
  const {
    userList,
    chatId, selectChat,
		unreadMessagesRef,
    chatName } = useContext(ChatContext)
  const { setVisible } = props

	const UserContact = props => {
		// Find unread messages
		const { contact } = props

		const [unreadCount, setUnreadCount] = useState(0)
		useEffect(() => {
			const um = unreadMessagesRef.current.filter(obj => obj.id === contact.id)
			console.log(um)
			setUnreadCount(um.length)
		}, [unreadMessagesRef.current])
		return (
			<div
				className={'grid grid-cols-[55px_1fr] py-3 pl-8 pr-10 border-b border-slate-600 hover:bg-slate-600 cursor-pointer ' + (chatId===contact.id?" bg-slate-500":"")}
				onClick={e => { selectChat(contact.id) }}
			>
				<div className={"w-full "  + (contact.active === false? "grayscale":"") }>
					<div className={"relative flex w-full h-full object-cover rounded-full bg-slate-600"}>
						<Identicon className={"m-auto"} size={40} value={String("0x" + Sha256(contact.fp)) } theme={"substrate"} />
						{(Number(unreadCount)===0)?
						<div className={"absolute bottom-0 right-0 text-lime-400"}>
							<BsCircleFill size={12} />
						</div>
							:
						<div className={"absolute flex bottom-0 right-0 bg-red-500 w-4 h-4 rounded-full"}>
							<span className={"text-white text-[8px] m-auto"}>{unreadCount}</span>
						</div>
						}
					</div>
				</div>
				<div className='w-full ml-5'>
					<span className={"text-lg text-slate-300"}>{contact.name}</span>
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
				<Identicon className={"m-auto ml-4"} size={30} value={String("0x" + Sha256(pubKeyFp)) } theme={"substrate"} />
        <span className='text-2xl text-gray-200 pl-2 py-3'>{userName}</span>
				<div className={"flex flex-grow"}></div>
				<div className={"flex space-x-2 text-gray-300 text-xl mr-2"}>
					{/*<div className={"flex w-8 h-8 m-auto cursor-pointer rounded-full bg-slate-600 hover:bg-slate-400"} onClick={e => { console.log(userName) }}>*/}
					{/*	<RiSettings4Line className={"m-auto"} />*/}
					{/*</div>*/}
					<div className={"flex w-8 h-8 m-auto cursor-pointer text-red-400 rounded-full bg-slate-600 hover:bg-slate-400"} onClick={e => { logout() }}>
						<CgLogOff className={"m-auto"} />
					</div>
				</div>
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
          <span className={"text-lg text-slate-300"}>Group</span>
          <span className={"text-base text-slate-400 font-light line-clamp-1"}>chat.message</span>
        </div>
      </div>
      {
        userList.map((contact) => (
          <UserContact key={contact.id} contact={contact} />
        ))
      }
    </div>
  )
}
