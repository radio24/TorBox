import { ContactList } from "./ContactList.jsx";
import { MessageBox } from "./MessageBox.jsx";
import { Sidebar } from "primereact/sidebar";
import {useContext, useEffect, useState} from "react";
import TorBoxLogo from "../../assets/torbox-icon-300x300.png";

import {HiMenu, HiOutlineChatAlt} from "react-icons/hi"
import {ChatContext} from "../../context/ChatContext.jsx";
import {UserContext} from "../../context/UserContext.jsx";
import {ProgressSpinner} from "primereact/progressspinner";
import "./Chat.css"
import {ProgressBar} from "primereact/progressbar";

export const Chat = props => {
	const {
		sessionLoading
	} = useContext(UserContext)

  const {
    chatName, chatLoading, miniLoading
  } = useContext(ChatContext)

  const [visible, setVisible] = useState(false)

  return (
    <div className='flex flex-col w-full h-full bg-slate-800 sm:p-10 p-5 overflow-hidden'>

      <div className='h-full rounded-xl overflow-hidden shadow-xl shadow-slate-900/50'>
        <div className={"relative flex bg-slate-700 shadow-md w-full h-[60px] p-4 border-b border-slate-600"}>
					{(miniLoading) &&
					<div className={"absolute left-0 bottom-0 w-full"}>
						<ProgressBar mode="indeterminate" style={{ height: '1px' }} />
					</div>
					}
          <div className={"flex w-full"}>
            <div className='hidden lg:flex h-[30px] text-lime-400 space-x-4 text-2xl'>
              <HiOutlineChatAlt className={"my-auto"} /> <span>CHAT SECURE</span>
            </div>
            <div className='flex lg:hidden h-[30px] text-lime-400 space-x-4 text-2xl' onClick={(e) => { setVisible(!visible) }}>
              <HiMenu className={"my-auto"} />
            </div>
            <span className={"m-auto text-white"}>{chatName}</span>
          </div>
          <div className={"flex-grow"}></div>
          <img src={TorBoxLogo} />
        </div>

        <div className={"flex w-full h-[calc(100%-60px)]"}>
          {(chatLoading)? "LOADING":
          <>
            {/*Contact list*/}
            <div className={"hidden lg:flex xl:flex 2xl:flex w-1/3"}>
              <ContactList {...{
                setVisible,
              }} />
            </div>

            <Sidebar className={"flex lg:hidden xl:hidden 2xl:hidden"} visible={visible} onHide={() => setVisible(false)} showCloseIcon={true}>
              <ContactList {...{
                setVisible,
              }} />
            </Sidebar>

            {/*Messages*/}
            <MessageBox />
          </>
          }
        </div>

      </div>

    </div>
  )
}
