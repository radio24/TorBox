import React from 'react'
import ReactDOM from 'react-dom/client'
import { PrimeReactProvider } from 'primereact/api';

import App from './App.jsx'
import './main.css'
import './fileshare.css'


ReactDOM.createRoot(document.getElementById('root')).render(
	<PrimeReactProvider>
		<App />
	</PrimeReactProvider>
)
