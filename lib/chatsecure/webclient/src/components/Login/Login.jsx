import "./Login.css"
import {Button} from "primereact/button";
import TorBoxLogo from "../../assets/torbox-icon-300x300.png";
import {Identicon} from "@polkadot/react-identicon";
import Sha256 from "crypto-js/sha256.js";
import {InputText} from "primereact/inputtext";
import {classNames} from "primereact/utils";
import {useContext, useState} from "react";
import {APIClient} from "../../hooks/APIClient.jsx";
import * as openpgp from "openpgp";
import {useFormik} from "formik";
import {UserContext} from "../../context/UserContext.jsx";

export const Login = props => {
  const {
    privKey, setPrivKey,
    pubKey, setPubKey,
    pubKeyFp, setPubKeyFp,
    userId, setUserId,
    token, setToken,
  } = useContext(UserContext)

  const doLogin = async (name) => {
    const api = APIClient()
    const data = await api.login(name, pubKey.armor())
    if (data) {
      setUserId(data.id)
      setToken(data.token)
    }
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

    // TODO: Set this keys in a context. Hide login when token is set
    setPrivKey(privateKey)
    setPubKey(publicKey)
    setPubKeyFp(publicKey.getFingerprint())
  }

  const onUsernameChange = async (e) => {
    generateRandomKeys(e.target.value)
    formik.setFieldValue('name', e.target.value);
  }

  const formik = useFormik({
    initialValues: {
      name: ''
    },
    validate: (data) => {
      let errors = {};

      if (!data.name || data.name === "") {
        errors.name = 'Username is required.';
      }
      else if (data.name.length<5) {
        errors.name = "Min. length 5 characters"
      }
      else if (!/^[A-Z0-9._-]+$/i.test(data.name)) {
        errors.name = "Characters not allowed"
      }

      return errors;
    },
    onSubmit: (data) => {
      // data && show(data);
      doLogin(data.name)
      formik.resetForm();
    },
  });

  const isFormFieldInvalid = (name) => !!(formik.touched[name] && formik.errors[name]);

  const getFormErrorMessage = (name) => {
    return isFormFieldInvalid(name) ? <small className="p-error mx-auto">{formik.errors[name]}</small> : <small className="p-error">&nbsp;</small>;
  };

  return (
    <div className={"flex flex-col h-full"}>
      {/*HEADER*/}
      <div className={"flex bg-gray-600 shadow-md w-full h-[60px] p-4"}>
        <div className={"flex w-full"}>
          <div className={"absolute flex w-[30px] h-[30px]"} onClick={(e) => { showContacts }}>
            <img src={TorBoxLogo} />
          </div>
          <span className={"m-auto text-white"}>SECURE CHAT</span>
        </div>
        <div className={"flex-grow"}></div>
      </div>

      <form onSubmit={formik.handleSubmit} className={"flex flex-col w-full h-full space-y-28 items-center"}>
        {/*TorBox / Identicon*/}
        <div className={"flex mt-[100px]"}>
          {pubKeyFp===""?
            // Show torbox logo if no name is set
            <div className={"flex w-[128px] h-[128px] bg-[#7fb931] rounded-xl border border-[#7fb931] mt-[8px]"}>
              <span className={"text-white -mt-[40px] mx-auto text-[135px] font-bold"}>T</span>
            </div>
            :
            // Show Identicon as avatar
            <div className={"border border-[#7fb931] rounded-xl"}>
              <Identicon className={"mx-auto"} size={128} value={String("0x" + Sha256(pubKeyFp)) } theme={"substrate"} />
            </div>
          }
        </div>

        {/*Username input*/}
        <div className={"flex flex-col w-full"}>
          <div className="p-float-label mx-auto">
            <InputText
              id="name"
              value={formik.values.name}
              className={classNames({ 'p-invalid': isFormFieldInvalid('name') })}
              onChange={onUsernameChange}
              autoComplete={"off"}
            />
            <label htmlFor="name">Username</label>
          </div>
          {getFormErrorMessage('name')}
        </div>

        {/*Connect button*/}
        <div className={"flex flex-col"}>
          <div className={"flex w-full mb-5"}>
            <span className={"mx-auto text-xs text-gray-400"}>TCS will generate random keys to encrypt your messages</span>
          </div>
          <Button
            label={"Connect"}
            type={"submit"}
            className={"mx-auto w-full"}
            disabled={isFormFieldInvalid('name')}
          />
        </div>

      </form>

    </div>
  )
}