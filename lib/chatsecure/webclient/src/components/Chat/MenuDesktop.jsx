import { useContext } from "react";

import Sha256 from "crypto-js/sha256.js";
import { Identicon } from "@polkadot/react-identicon";
import { UserContext } from "../../context/UserContext.jsx";

import {HiMenu, HiKey, HiChat, HiLogout} from "react-icons/hi"
import TorBoxLogo from "../../assets/torbox-icon-300x300.png";

export const MenuDesktop = props => {

  const {
    visible,
    setVisible,
    menuUser,
    setMenuUser,
    chatName 
  } = props

  const {
    pubKeyFp, userName, logout, downloadKeys
  } = useContext(UserContext)

  return (
    <div className={"hidden md:grid grid-cols-[auto_1fr_auto_auto_auto_auto] gap-6 place-content-center w-full"}>
      <div className="grid grid-cols-[auto_1fr] gap-6">
        <div>
          <img className="h-[30px] shadow-lg text-black" src={TorBoxLogo} />
        </div>
        <div className="text-xl font-light text-slate-200">
          <span className="font-bold mr-1">TorBox</span> Chat Secure
        </div>
      </div>
      <div className="text-slate-200 text-lg self-center text-center items-center">
        <HiChat className="mr-2 inline-block text-2xl pb-1" /> {chatName}
      </div>
      <div className="bg-slate-800 px-2 rounded-full shadow-2xl text-black grid place-content-center">
        <Identicon size={20} value={String("0x" + Sha256(pubKeyFp)) } theme={"substrate"} />
      </div>
      <div className="text-lg font-extralight text-slate-300">{userName}</div>
      <div
          className="cursor-pointer bg-lime-600 px-4 text-lg rounded-xl shadow-lg text-black"
          onClick={downloadKeys}
      >Keys <HiKey className="ml-1 inline-block" /></div>
      <div onClick={() => logout() } className="cursor-pointer bg-red-500 px-4 text-lg rounded-xl shadow-lg text-black">Logout <HiLogout className="ml-1 inline-block" /></div>
    </div>
  )
}
