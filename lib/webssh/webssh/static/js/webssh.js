

const key_file = document.getElementById('privatekey');
key_file.addEventListener("change", handleFiles, false);

function handleFiles() {
    const filename = this.files[0].name;
    const webssh_get_key = document.getElementById('webssh-get-key')

    webssh_get_key.innerHTML = `<span>🟢 Key OK : ${filename} </span>`
}

const getKeyfile = () => {
    key_file.click()
}

const loginType = (type) => {

    const content_key = document.getElementById('privatekey-content')
    const content_password = document.getElementById('password-content')
    const password_input = document.getElementById('password')

    if( type == 'password' )
    {
        content_key.style.display = 'none'
        content_password.style.display = 'block'
        password_input.setAttribute("required", "true")
    }
    else
    {
        content_key.style.display = 'block'
        content_password.style.display = 'none'
        password_input.removeAttribute("required")
    }
}
