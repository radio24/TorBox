import { useState, useContext } from 'react'
import PrimeReact from 'primereact/api'
import TorBoxLogo from './assets/torbox-icon-300x300.png'
import { UserContext } from "./context/UserContext.jsx";
import {Login} from "./components/Login/Login.jsx"
import {Chat} from "./components/Chat/Chat.jsx";
import {ChatProvider} from "./context/ChatContext.jsx";

function App() {
  PrimeReact.ripple = true

  const { token } = useContext(UserContext)

  // const [privKey, setPrivKey] = useState(null)
  // const [pubKey, setPubKey] = useState(null)
  // const [pubKeyFp, setPubKeyFp] = useState("")
  // const [userId, setUserId] = useState(null)
  // const [token, setToken] = useState(null)

  return (
    <div id={"app"} className="flex flex-col w-full h-full">
      {/*CONTENT*/}
      <div className={"w-full h-full overflow-hidden"}>
        {token === null ?
        // LOGIN
        <Login {...{
          // privKey, setPrivKey,
          // pubKey, setPubKey,
          // pubKeyFp, setPubKeyFp,
          // userId, setUserId,
          // token, setToken,
        }} />
        :
        // CHAT
        <ChatProvider>
          <Chat {...{
            // privKey, pubKey, pubKeyFp, token, userId
          }} />
        </ChatProvider>
        }
      </div>
    </div>
  )
}

export default App
