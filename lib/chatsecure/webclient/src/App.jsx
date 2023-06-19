import { useState, useContext } from 'react'
import PrimeReact from 'primereact/api'
import { UserContext } from "./context/UserContext.jsx";
import {Login} from "./components/Login/Login.jsx"
import {Chat} from "./components/Chat/Chat.jsx";
import {ChatProvider} from "./context/ChatContext.jsx";
import {ProgressSpinner} from "primereact/progressspinner";

function App() {
  PrimeReact.ripple = true

  const { token, sessionLoading } = useContext(UserContext)

  return (
    <div id={"app"} className="flex flex-col w-full h-full">
      {/*CONTENT*/}
      <div className={"w-full h-full overflow-hidden"}>
				{(sessionLoading)?
				<div className={"flex flex-col w-full h-full bg-slate-600"}>
					<div className={"flex flex-col space-y-2 m-auto"}>
						<ProgressSpinner style={{width: '50px', height: '50px'}} strokeWidth="5" animationDuration=".9s" />
						<span className={"text-white"}>LOADING</span>
					</div>
				</div>
					:
					(token === null) ?
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
