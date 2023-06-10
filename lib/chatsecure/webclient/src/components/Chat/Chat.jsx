import { ContactList } from "./ContactList.jsx";
import { MessageBox } from "./MessageBox.jsx";
import { Sidebar } from "primereact/sidebar";
import { useContext, useEffect, useState } from "react";

import { ChatContext } from "../../context/ChatContext.jsx";
import { UserContext } from "../../context/UserContext.jsx";
import { ProgressSpinner } from "primereact/progressspinner";
import "./Chat.css"
import { ProgressBar } from "primereact/progressbar";
import { MenuUser } from "./MenuUser.jsx";
import { MenuMobile } from "./MenuMobile.jsx";
import { MenuDesktop } from "./MenuDesktop.jsx";

export const Chat = props => {
  const {
    sessionLoading
  } = useContext(UserContext)

  const {
    chatName, chatLoading, miniLoading
  } = useContext(ChatContext)

  const [visible, setVisible] = useState(false)
  const [menuUser, setMenuUser] = useState(false)

  return (
    <div className='flex flex-col w-full h-full bg-slate-800 sm:p-10 p-0 overflow-hidden'>

      <div className='h-full rounded-xl overflow-hidden shadow-xl shadow-slate-900/50'>
        <div className='relative flex
        bg-gradient-to-b from-slate-600/95 to-slate-700
        border-b border-slate-600/50
        shadow-2xl shadow-slate-900/30 w-full h-[60px] px-5'>

          {(miniLoading) &&
            <div className={"absolute left-0 bottom-0 w-full"}>
              <ProgressBar mode="indeterminate" style={{ height: '1px' }} />
            </div>
          }

          <MenuDesktop
            visible={visible}
            setVisible={setVisible}
            menuUser={menuUser}
            setMenuUser={setMenuUser}
            chatName={chatName}
          />

          <MenuMobile
            visible={visible}
            setVisible={setVisible}
            menuUser={menuUser}
            setMenuUser={setMenuUser}
            chatName={chatName}
          />

        </div>

        <div className={"flex w-full h-[calc(100%-60px)]"}>
          
          {(chatLoading) ? "LOADING" :
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

              <Sidebar visible={menuUser} position="right" onHide={() => setMenuUser(false)}>
                <MenuUser />
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
