import {HiMenu, HiChat, HiUser} from "react-icons/hi"

export const MenuMobile = props => {

  const {
    visible,
    setVisible,
    menuUser,
    setMenuUser,
    chatName 
  } = props

  return (
    <div className={"grid grid-cols-[auto_1fr_auto] place-content-center md:hidden w-full"}>
      <div className="text-3xl text-lime-500" onClick={() => { setVisible(!visible) }}>
        <HiMenu className={"my-auto"} />
      </div>
      <div className="text-slate-200 text-lg self-center text-center items-center">
        <HiChat className="mr-2 inline-block text-2xl pb-1" /> {chatName}
      </div>
      <div className="text-3xl text-slate-200" onClick={() => { setMenuUser(!menuUser) }}>
        <HiUser className={"my-auto"} />
      </div>
    </div>
  )
}
