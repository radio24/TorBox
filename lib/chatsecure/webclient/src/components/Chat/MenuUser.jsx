import { useContext } from "react";

import Sha256 from "crypto-js/sha256.js";
import { Identicon } from "@polkadot/react-identicon";
import { UserContext } from "../../context/UserContext.jsx";
import {HiKey, HiLogout} from "react-icons/hi"
import TorBoxLogo from "../../assets/torbox-icon-300x300.png";

export const MenuUser = props => {
  const {
    pubKeyFp, userName, logout, downloadKeys
  } = useContext(UserContext)

  return (
    <div className="grid gap-7 place-content-center">
      <div className="bg-slate-800 rounded-full p-6 shadow-2xl text-black">
        <Identicon size={170} value={String("0x" + Sha256(pubKeyFp)) } theme={"substrate"} />
      </div>
      <div className='text-center'>
        <div className="text-base text-slate-400">username</div>
        <div className="text-3xl text-slate-200">{userName}</div>
      </div>
      <div className='text-center space-y-5'>
        <div
            className="bg-lime-600 px-3 pt-1 pb-1.5 text-lg rounded-xl shadow-lg text-black"
            onClick={downloadKeys}
        >
            Download Keys <HiKey className="ml-1 inline-block" />
        </div>
        <div onClick={() => logout() } className="bg-rose-600 px-3 pt-1 pb-1.5 text-lg rounded-xl shadow-lg text-black">Logout <HiLogout className="ml-1 inline-block" /></div>
      </div>
      <div className="mt-16 grid place-content-center">
        <img className="h-[50px] shadow-lg text-black" src={TorBoxLogo} />
      </div>
      <div className="text-center text-slate-500">
        TorBox Chat Secure TCS
      </div>
    </div>
  )
}
