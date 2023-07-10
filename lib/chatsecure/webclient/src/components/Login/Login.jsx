import "./Login.css"
import { Button } from "primereact/button";
import TorBoxLogo from "../../assets/torbox-icon-300x300.png";
import { Identicon } from "@polkadot/react-identicon";
import Sha256 from "crypto-js/sha256.js";
import { InputText } from "primereact/inputtext";
import { classNames } from "primereact/utils";
import {useContext, useEffect, useRef, useState} from "react";
import { APIClient } from "../../hooks/APIClient.jsx";
import { useFormik } from "formik";
import { UserContext } from "../../context/UserContext.jsx";

export const Login = props => {
  const {
    pubKeyFp,
    generateRandomKeys,
    login, loginWithKey,
  } = useContext(UserContext)

  const fileInputRef = useRef()

  const onUsernameChange = async (e) => {
    // generateRandomKeys(e.target.value)
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
      else if (data.name.length < 5) {
        errors.name = "Min. length 5 characters"
      }
      else if (!/^[A-Z0-9_-]+$/i.test(data.name)) {
        errors.name = "Only alphanumeric allowed"
      }

      return errors;
    },
    onSubmit: async (data) => {
      // data && show(data);
      const loginResult = await login(data.name)
      formik.resetForm();
    },
  });

  const isFormFieldInvalid = (name) => !!(formik.touched[name] && formik.errors[name]);

  const getFormErrorMessage = (name) => {
    return isFormFieldInvalid(name) ? <small className="p-error mx-auto">{formik.errors[name]}</small> : <small className="p-error">&nbsp;</small>;
  };

  const loadCustomKeys = async (e) => {
      const content = await e.target.files[0].text()
      console.log(content)
      loginWithKey(content)
  }


  useEffect(() => {
    const delayRandomKeys = setTimeout(() => {
      generateRandomKeys(formik.values.name)
    }, 100)

    return () => clearTimeout(delayRandomKeys)
  }, [formik.values.name])

  return (
    <div className='w-full h-full bg-gradient-to-t from-slate-700 to-slate-800
    relative grid place-content-center'>

      <div className="w-[140px] h-[140px] p-[20px] bg-[#7fb931] overflow-hidden rounded-full place-self-center
      shadow-lg shadow-slate-900/80">
        {
          pubKeyFp === '' ?
            <img className="w-[100px] text-center" src={TorBoxLogo} />
            :
            <Identicon className={"mx-auto"} size={100} value={String("0x" + Sha256(pubKeyFp))} theme={"substrate"} />
        }
      </div>

      <div className="text-slate-200 text-3xl font-extralight text-center mt-7 mb-10">
        <span className="font-medium">TorBox</span> Chat Secure
      </div>

      <form onSubmit={formik.handleSubmit} className="grid place-content-center">

          <div className="text-center font-medium text-slate-300 mb-3">
            Enter your alias
          </div>

          <input
            type="text"
            id="name"
            value={formik.values.name}
            onChange={onUsernameChange}
            autoComplete={"off"}
            maxLength={24}
            placeholder="KevinMitnick"
            className="text-center font-light w-[250px]
            shadow-lg shadow-slate-800/60
            placeholder:text-slate-300 block bg-white border-2 border-slate-300 rounded-xl py-2 focus:outline-none focus:border-lime-500 focus:ring-lime-500 focus:ring-3
            "
          ></input>

          <div className="text-center text-sm font-light text-slate-400 mt-3">
            TCS will generate random keys<br></br>to encrypt your messages
          </div>

          <input
            value={"Connect Now"}
            type={"submit"}
            className='bg-gradient-to-b from-lime-500 to-lime-600 mt-6
            shadow-lg shadow-slate-800/60
            px-3 pt-2 pb-2.5 text-base text-center rounded-xl text-black font-light cursor-pointer'
            disabled={isFormFieldInvalid('name')}
          />

          <div className="text-center">
          {getFormErrorMessage('name')}
          </div>

          <div className="border-t border-slate-600 my-3"></div>

          <input
            ref={fileInputRef}
            onChange={loadCustomKeys}
            type="file"
            style={{ display: "none" }}
            // multiple={false}
          />
          <div className='bg-gradient-to-b from-slate-400 to-slate-500 mt-6
          shadow-lg shadow-slate-800/60
          px-3 pt-2 pb-2.5 text-base text-center rounded-xl text-black font-light cursor-pointer'
               onClick={(e) => {fileInputRef.current.click() } }
          >
              Load your key
          </div>

          <div className="text-center text-sm font-light text-slate-400 mt-3">
            Upload your key to resume<br></br>your conversations
          </div>

      </form>

    </div>
  )
}
