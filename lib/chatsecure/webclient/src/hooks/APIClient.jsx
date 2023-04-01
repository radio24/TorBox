import axios from "axios";
import { config } from "../utils/constants"

export const APIClient = (token=false) => {
  const LOGIN_URL = `${config.url.API_URL}/login`
  const USERLIST_URL = `${config.url.API_URL}/users`
  const GROUPLIST_URL = `${config.url.API_URL}/groups`
  const USERMSGLIST_URL = `${config.url.API_URL}/user_msg`
  const GROUPMSGLIST_URL = `${config.url.API_URL}/group_msg`

  const getHeaders = async () => {
    return {
        'Authorization': `Token ${token}`
      }
  }
  const login = async (name, pubkey) => {
    const r = await axios.post(LOGIN_URL, {
      name: name,
      pubkey: pubkey
    })
    if (r.status == 200) {
      return r.data
    }
    else {
      return false
    }
  }

  const getUserList = async () => {
    if (token == false) return false

    const r = await axios.get(USERLIST_URL, {headers: await getHeaders()})
    if (r.status==200) {
      return r.data
    }
    else {
      return false
    }
  }

  const getGroupList = async () => {
    if (token == false) return false

    const r = await axios.get(GROUPLIST_URL, {headers: await getHeaders()})
    if (r.status==200) {
      return r.data
    }
    else {
      return false
    }
  }

  const getUserMessageList = async (sender_id) => {
    if (token == false) return false

    const r = await axios.get(USERMSGLIST_URL + "/" + sender_id, {
      // params: {sender_id: sender_id},
      headers: await getHeaders()
    })
    if (r.status==200) {
      return r.data
    }
    else {
      return false
    }
  }

  const getGroupMessageList = async () => {
    if (token == false) return false

    const r = await axios.get(GROUPMSGLIST_URL, {headers: await getHeaders()})
    if (r.status==200) {
      return r.data
    }
    else {
      return false
    }
  }

  return {
    login,
    getUserList,
    getGroupList,
    getUserMessageList,
    getGroupMessageList
  }
}