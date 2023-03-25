import { useState } from 'react'
import PrimeReact from 'primereact/api'
import TorBoxLogo from './assets/torbox-icon-300x300.png'
import {Login} from "./components/Login/Login.jsx"
import {Chat} from "./components/Chat/Chat.jsx";

function App() {
  PrimeReact.ripple = true

  const [privKey, setPrivKey] = useState(null)
  const [pubKey, setPubKey] = useState(null)
  const [pubKeyFp, setPubKeyFp] = useState("")
  const [userId, setUserId] = useState(null)
  const [token, setToken] = useState(null)

  return (
    <div id={"app"} className="flex flex-col w-full h-full">
      {/*CONTENT*/}
      <div className={"w-full h-full overflow-hidden"}>
        {token === null ?
        // LOGIN
        <Login {...{
          privKey, setPrivKey,
          pubKey, setPubKey,
          pubKeyFp, setPubKeyFp,
          userId, setUserId,
          token, setToken,
        }} />
        :
        // CHAT
        <Chat {...{
          privKey, pubKey, pubKeyFp, token, userId
        }} />
        }
      </div>
    </div>
  )
}

export default App
