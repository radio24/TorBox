import {createContext, useEffect, useRef, useState} from "react";
import Cookies from "js-cookie"
import * as openpgp from "openpgp";
import {APIClient} from "../hooks/APIClient.jsx";

export const UserContext = createContext();

export const UserProvider = (props) => {
	const [privKey, setPrivKey] = useState(null)
	const [pubKey, setPubKey] = useState(null)
	const [pubKeyFp, setPubKeyFp] = useState("")
	const [userId, setUserId] = useState(null)
	const [userName, setUserName] = useState(null)
	const [messages, setMessages] = useState([])
	const [token, setToken] = useState(null)
	const [sessionLoading, setSessionLoading] = useState(false)

	const privKeyRef = useRef()
	const pubKeyRef = useRef()

	const loginWithKey = async (_privateKey) => {
		const myKey = await openpgp.readKey({ armoredKey: _privateKey })
		const myPubKey = myKey.toPublic()

		// console.log("pubKey:", myPubKey.armor())
		const uid = String(myKey.getUserIDs())
		const result = uid.match(/\<(.*)?\>/gs)
		// console.log(result)
		if (result === null) {
			//failed to load key alert
		}
		const email = result[0]
		const name = email.split("@")[0].slice(1)
		// console.log(name)

		setUserName(name)
		setPrivKey(myKey)
		setPubKey(myPubKey)
		setPubKeyFp(myPubKey.getFingerprint())

		login(name, myPubKey.armor())
	}

	const downloadKeys = async () => {
		const element = document.createElement("a");
		element.setAttribute("id", "download-key");
		const file = new Blob([privKey.armor()], { type: "text/plain" });
		element.href = URL.createObjectURL(file);
		element.download = `${userName}.asc`;

		// simulate link click
		document.body.appendChild(element); // Required for this to work in FireFox
		element.click();
		document.body.removeChild(element)
	}

	const decryptMessage = async (txt) => {
		const privateKey = privKey

		const encrypted = txt
		const message = await openpgp.readMessage({
			armoredMessage: encrypted // parse armored message
		});
		const { data: decrypted, signatures } = await openpgp.decrypt({
			message,
			// verificationKeys: publicKey, // optional
			decryptionKeys: privateKey
		});
		// TODO: Check calls to this function
		return decrypted
	}

	const encryptMessage = async (text, publicKeysArmored) => {
		const privateKeyArmored = privKey.armor();    // encrypted private key
		const plaintext = text;

		const publicKeys = await Promise.all(publicKeysArmored.map(armoredKey => openpgp.readKey({ armoredKey })));

		const privateKey = await openpgp.readKey({ armoredKey: privateKeyArmored })

		const message = await openpgp.createMessage({ text: plaintext });
		const encrypted = await openpgp.encrypt({
				message, // input as Message object
				encryptionKeys: publicKeys,
				signingKeys: privateKey // optional
		});
		return encrypted
	}

	const generateRandomKeys = async (name) => {
		if (name === "" || name === null) {
			setPubKeyFp("")
			return false
		}
		const email = name.replace(" ", "_").toLowerCase() + "@torboxchatsecure.onion"

		const { privateKey, publicKey, revocationCertificate } = await openpgp.generateKey({
			curve: 'curve25519',
			userIDs: [{ name: name, email: email }], // you can pass multiple user IDs
			// passphrase: 'super long and hard to guess secret',
			format: 'object' // output key format, defaults to 'armored' (other options: 'binary' or 'object')
		});

		setUserName(name)
		setPrivKey(privateKey)
		setPubKey(publicKey)
		setPubKeyFp(publicKey.getFingerprint())
	}

	const login = async (name, _pubKey=null) => {
		const api = APIClient()
		let data = null;
		if (_pubKey === null)
			data = await api.login(name, pubKey.armor())
		else
			data = await api.login(name, _pubKey)
		if (data !== null) {
			setUserId(data.id)
			setToken(data.token)
		}
	}

	const logout = async () => {
		setSessionLoading(true)
		setPrivKey(null)
		setPubKey(null)
		setPubKeyFp(null)
		setMessages([])
		setUserId(null)
		setUserName(null)
		setToken(null)
		Cookies.remove("tcs_auth")
		window.location.reload()
	}

	const checkSession = async () => {
		setSessionLoading(true)
		let cookies = Cookies.get("tcs_auth")
		if (cookies !== undefined) {
			cookies = JSON.parse(cookies)
			const {
				userId:_userId,
				userName:_userName,
				token:_token,
				privKey:privKeyArmored,
				pubKey:pubKeyArmored
			} = cookies

			if (_token !== undefined) {

				setUserId(_userId)
				setUserName(_userName)
				const _privKey = await openpgp.readKey({armoredKey: privKeyArmored})
				const _pubKey = await openpgp.readKey({armoredKey: pubKeyArmored})
				setPrivKey(_privKey)
				setPubKey(_pubKey)
				setPubKeyFp(_pubKey.getFingerprint())
				setToken(_token)
			}
		}
		setSessionLoading(false)
	}

	const setSession = () => {
		if (token === null)
			return
		const tcs_auth = {
			"userId": userId,
			"userName" : userName,
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
		userName, setUserName,
		// userList, setUserList,
		messages, setMessages,
		token, setToken,
		login, logout, loginWithKey,
		sessionLoading,
		generateRandomKeys,
		encryptMessage, decryptMessage,
		downloadKeys
	  }}
	>
	  {props.children}
	</UserContext.Provider>
  );
};
