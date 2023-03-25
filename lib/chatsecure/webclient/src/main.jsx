import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
// import "primereact/resources/themes/lara-light-indigo/theme.css"
import "primereact/resources/primereact.min.css"
import "primeicons/primeicons.css"
import './css/tailwind.css'
import "primereact/resources/themes/bootstrap4-light-purple/theme.css"
import './css/global.css'


ReactDOM.createRoot(document.getElementById('root')).render(
  // <React.StrictMode>
    <App />
  // </React.StrictMode>,
)
