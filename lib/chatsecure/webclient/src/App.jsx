import { useState, useContext } from 'react'
import PrimeReact from 'primereact/api'
import { UserContext } from "./context/UserContext.jsx";
import {Login} from "./components/Login/Login.jsx"
import {Chat} from "./components/Chat/Chat.jsx";
import {ChatProvider} from "./context/ChatContext.jsx";

function App() {
  PrimeReact.ripple = true

  const { token } = useContext(UserContext)

  return (
    <div id={"app"} className="flex flex-col w-full h-full">
      {/*CONTENT*/}
      <div className={"w-full h-full overflow-hidden"}>
        {token === null ?
        // LOGIN
        <Login />
        :
        // CHAT
        <ChatProvider>
          <Chat />
        </ChatProvider>
        }
      </div>
    </div>
  )
}

export default App
