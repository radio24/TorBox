export const MessageOut = props => {
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
      {props.text}
      </div>
      <div className='sm:mr-[40px] mr-[20px] place-self-start'>
        <img className='h-[44px] w-[44px] object-cover rounded-full'
          src="https://demos.pixinvent.com/vuexy-nextjs-admin-template/demo-1/images/avatars/1.png" />
      </div>
    </div>
  )
}