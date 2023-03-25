export const MessageIn = props => {
  return (
    <div className='grid gap-4 w-full
    sm:grid-cols-[84px_2fr_1fr]
    grid-cols-[64px_1fr]
    place-items-start
    '>
      <div className='sm:ml-[40px] ml-[20px]'>
        <img className='h-[44px] w-[44px] object-cover rounded-full'
          src="https://demos.pixinvent.com/vuexy-nextjs-admin-template/demo-1/images/avatars/1.png" />
      </div>
      <div className="bg-slate-700 w-fit
      px-5 pt-2 pb-2.5 mr-5 sm:mr-0
      rounded-tr-2xl rounded-bl-2xl rounded-br-2xl
      text-base text-slate-300 font-light">
      {props.text}
      </div>
      <div className="hidden sm:block"></div>
    </div>
  )
}