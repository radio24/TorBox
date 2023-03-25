import avatarDemo from "../../assets/avatar.png";
import "./ContactList.css"
import Sha256 from "crypto-js/sha256.js";
import {Identicon} from "@polkadot/react-identicon";

export const ContactList = props => {
  const { userList, setVisible } = props

  return (
    <div className='flex flex-col w-full h-full overflow-auto
    bg-slate-700 p-0
    '>
      <div className='flex'
        onClick={e => { setVisible(false) }}>
        <span className='text-2xl text-lime-500 pl-8 pt-5 pb-2'>Chats</span>
      </div>
      {
        userList.map((chat) => (
          <div key={chat.fp} className='grid grid-cols-[55px_1fr] py-3 pl-8 pr-10
          border-b border-slate-600
          hover:bg-slate-600'>
            <div className='w-full'>
              {/*<img src={chat.image} className='h-full w-full object-cover rounded-full' />*/}
              <div className={"flex w-full h-full object-cover rounded-full bg-slate-600"}>
                <Identicon className={"m-auto"} size={40} value={String("0x" + Sha256(chat.fp)) } theme={"substrate"} />
              </div>
            </div>
            <div className='w-full ml-5'>
              <span className={"text-lg text-slate-300"}>{chat.name}</span>
              <span className={"text-base text-slate-400 font-light line-clamp-1"}>chat.message</span>
            </div>
          </div>
        ))
      }
    </div>
  )
}