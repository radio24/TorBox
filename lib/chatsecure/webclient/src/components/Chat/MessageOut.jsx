import {useContext, useEffect, useState} from "react";
import {UserContext} from "../../context/UserContext.jsx";
import {Identicon} from "@polkadot/react-identicon";
import Sha256 from "crypto-js/sha256.js";

export const MessageOut = props => {
  const {
    pubKeyFp,
    userId,
		decryptMessage
  } = useContext(UserContext)

	const [message, setMessage] = useState("")

	useEffect(() => {
		decryptMessage(props.text).then(r => setMessage(r))
	})

  return (
    <div className='grid gap-4 w-full
    sm:grid-cols-[1fr_2fr_84px]
    grid-cols-[1fr_64px]
    place-items-end
    '>
      <div className="hidden sm:block"></div>
      <div className="bg-lime-600 w-fit
      px-5 pt-2 pb-2.5 ml-5 sm:ml-0
      rounded-tl-2xl rounded-bl-2xl rounded-br-2xl
      text-base text-slate-50 font-light">
      {message}
      </div>
      <div className='sm:mr-[40px] mr-[20px] place-self-start'>
        <div className={"flex w-full h-full object-cover rounded-full bg-slate-600"}>
          <Identicon className={"mx-auto"} size={44} value={String("0x" + Sha256(pubKeyFp)) } theme={"substrate"} />
        </div>
      </div>
    </div>
  )
}
