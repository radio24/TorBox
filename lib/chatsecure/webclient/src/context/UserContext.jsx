import {createContext, useEffect, useRef, useState} from "react";
import Cookies from "js-cookie"
import * as openpgp from "openpgp";

export const UserContext = createContext();

export const UserProvider = (props) => {
  const [privKey, setPrivKey] = useState(null)
  const [pubKey, setPubKey] = useState(null)
  const [pubKeyFp, setPubKeyFp] = useState("")
  const [userId, setUserId] = useState(null)
  const [messages, setMessages] = useState([])
  const [token, setToken] = useState(null)

	const privKeyRef = useRef()
	const pubKeyRef = useRef()

	const checkSession = async () => {
		let cookies = Cookies.get("tcs_auth")
		if (cookies !== undefined) {
			cookies = JSON.parse(cookies)
			const {
				userId:_userId,
				token:_token,
				privKey:privKeyArmored,
				pubKey:pubKeyArmored
			} = cookies

			if (_token !== undefined) {

				setUserId(_userId)
				const _privKey = await openpgp.readKey({armoredKey: privKeyArmored})
				const _pubKey = await openpgp.readKey({armoredKey: pubKeyArmored})
				setPrivKey(_privKey)
				setPubKey(_pubKey)
				setPubKeyFp(_pubKey.getFingerprint())
				setToken(_token)
			}
		}
	}

	const setSession = () => {
		if (token === null)
			return
		const tcs_auth = {
			"userId": userId,
			"token": token,
			"privKey": privKeyRef.current.armor(),
			"pubKey": pubKeyRef.current.armor()
		}
		Cookies.set("tcs_auth", JSON.stringify(tcs_auth))
	}

	useEffect(() => {
		if (privKey !== null) {
			privKeyRef.current = privKey
		}
	}, [privKey])

	useEffect(() => {
		if (pubKey !== null) {
			pubKeyRef.current = pubKey
		}
	}, [pubKey])

	useEffect(() => {
		setSession()
	}, [token])

	useEffect(() => {
		checkSession()
	}, [])


  return (
    <UserContext.Provider
      value={{
        privKey, setPrivKey,
        pubKey, setPubKey,
        pubKeyFp, setPubKeyFp,
        userId, setUserId,
        // userList, setUserList,
        messages, setMessages,
        token, setToken,
      }}
    >
      {props.children}
    </UserContext.Provider>
  );
};
