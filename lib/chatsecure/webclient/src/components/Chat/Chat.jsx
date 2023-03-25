import avatarDemo from '../../assets/avatar.png'
import { ContactList } from "./ContactList.jsx";
import { MessageBox } from "./MessageBox.jsx";
import { Sidebar } from "primereact/sidebar";
import {useEffect, useState} from "react";
// import { socket } from "./socket"
import TorBoxLogo from "../../assets/torbox-icon-300x300.png";
import {APIClient} from "../../hooks/APIClient.jsx";

import {HiMenu, HiOutlineChatAlt} from "react-icons/hi"
import {io} from "socket.io-client";

export const Chat = props => {
  const {
    privKey, pubKey, pubKeyFp, token, userId
  } = props

  const [userList, setUserList] = useState([])
  const [chatName, setChatName] = useState("Default")
  const [chatId, setChatId] = useState(1)  // Default group
  const [chatGroup, setChatGroup] = useState(true)  // Start showing group
  const [chatMessages, setChatMessages] = useState([])

  const api = APIClient(token)

  // const URL = process.env.NODE_ENV === 'production' ? undefined : 'http://localhost:5000';
  const URL = 'http://127.0.0.1:5000';
  const socket = io(URL, {auth: {token: token}});

  const [visible, setVisible] = useState(false)

  const init = async () => {
    api.getGroupList().then(r => { console.log(r) })
    api.getUserList().then(r => { setUserList(r); console.log(r); })

    // api.getGroupMessageList().then(r => { setChatMessages(r) })
  }

  useEffect(() => {
    // no-op if the socket is already connected
    if (token !== null && token !== "") {
      socket.connect();
      init()
      console.log("--- GO ---")
    }

    return () => {
      socket.disconnect();
    };
  }, []);

  return (
    <div className='flex flex-col w-full h-full bg-slate-800 sm:p-10 p-5 overflow-hidden'>

      <div className='h-full rounded-xl overflow-hidden shadow-xl shadow-slate-900/50'>
        <div className={"flex bg-slate-700 shadow-md w-full h-[60px] p-4 border-b border-slate-600"}>
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
          {/*Contact list*/}
          <div className={"hidden lg:flex xl:flex 2xl:flex w-1/3"}>
            <ContactList {...{userList, setVisible}} />
          </div>

          <Sidebar className={"flex lg:hidden xl:hidden 2xl:hidden"} visible={visible} onHide={() => setVisible(false)} showCloseIcon={true}>
            <ContactList {...{userList, setVisible}} />
          </Sidebar>

          {/*Messages*/}
          <MessageBox {...{
            userId, chatId, chatGroup, socket,
            chatMessages, setChatMessages,
          }} />
        </div>

      </div>

    </div>
  )
}