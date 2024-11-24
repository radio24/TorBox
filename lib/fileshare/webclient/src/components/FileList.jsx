import { useState, useEffect } from 'react';
import { Column } from 'primereact/column';
import { getIconForFile, getIconForFolder } from 'vscode-icons-js';
import {DataTable} from "primereact/datatable";
import {BsCloudArrowUp, BsFolder} from "react-icons/bs";
import {FaArrowLeft, FaUpload, FaDownload, FaHome } from "react-icons/fa";
import {Tooltip} from "primereact/tooltip";
import {CgSpinner} from "react-icons/cg";
import { config } from "../constants.js";


export const FileList = (props) => {
	const {currentDir, setCurrentDir, toast, fileUploadRef} = props;
	// Use state to store the data gotten from the server
	const [dataCache, setDataCache] = useState([]);
	const [currentDirObject, setCurrentDirObject] = useState([]);
	const [treeData, setTreeData] = useState([]);
	const [loading, setLoading] = useState(false)

	const copyFileURLToClipboard = (e) => {
		const data = e.target
		// Copy the file URL to clipboard
		const text = 'pending';

		navigator.clipboard.writeText(text)
	}

	const nameTemplate = (node, options) => {
		const data = node.data;
		// Get icon for folder or file
		const icon = data.type === 'Folder' ? getIconForFolder(data.name.toLowerCase()) : getIconForFile(data.name.toLowerCase());
		return (
			<div className='select-none
			grid gap-5 grid-cols-[46px_1fr_20px] md:grid-cols-[50px_1fr_20px]
			text-sm md:text-base'>
				<img
					className='ml-6'
					src={'./assets/icons/' + icon}
					onError={t => t.target.src = './assets/icons/default_file.svg'}
					alt="file"
				/>
				<span className='text-ellipsis text-slate-200 overflow-hidden font-normal'>{data.name}</span>
				<div></div>
			</div>
		);
	}

	const sizeTemplate = (node) => {
		const data = node.data;
		return (
			<div className={"relative w-full pr-[90px] text-right font-light text-slate-300/70 text-sm md:text-base"}>
				<span>{data.size}</span>
				{/*{data.type !== 'Folder' &&*/}
				{/*	<div*/}
				{/*		className={"absolute right-5 top-1 cursor-pointer z-10 copy-path"}*/}
				{/*		data-pr-tooltip={"Copy link"}*/}
				{/*		data-pr-position={"bottom"}*/}
				{/*		data-pr-showdelay={"1000"}*/}
				{/*		onClick={(e) => { copyFileURLToClipboard(e) e.preventDefault(); }}*/}
				{/*	>*/}
				{/*		<FaRegCopy />*/}
				{/*	</div>*/}
				{/*}*/}
			</div>
		);
	}

	const getTreeData = (directoryPath='') => {
		if (loading)
			return false

		setLoading(true)

		// if directoryPath is empty, use currentDir.path
		if (directoryPath === '') {
			if (currentDir.path)
				directoryPath = currentDir.path
		}
		// Check if directoryPath is in dataCache already, otherwise fetch the data
		if (dataCache[directoryPath] !== undefined) {
			setCurrentDirObject(dataCache[directoryPath].current)
			setCurrentDir(dataCache[directoryPath].current)
			setTreeData(dataCache[directoryPath].tree)
			setLoading(false)
		}
		else {
			setTreeData([])

      fetch(config.url.API_URL + '/get_tree?path=' + directoryPath)
        .then((response) => response.json())
        .then((data) => {
          setCurrentDirObject(data.current)
          setCurrentDir(data.current)
          setTreeData(data.tree);
          setDataCache({...dataCache, [directoryPath]: data})
					setLoading(false)
        });
    }


	}

	const handleRowClick = (event) => {
		const data = event.data.data;
		if (data.type === 'Folder') {
			// Load the data for the new directory
			getTreeData(data.path)
		}
		else {
			// Check if current directory has 'r' permission
			if (!currentDirObject.permissions.includes('r')) {
				toast.current.show({severity: 'error', summary: 'Permission denied', detail: 'Insufficient permission to read this file', life: 3000});
				setLoading(false)
				return
    	  }

      // Download the file
			let filePath = currentDirObject.path + '/' + data.name
			// replace any duplicated / to a single /
			filePath = filePath.replace(/\/+/g, '/')
			// replace starting slash
			filePath = filePath.replace(/^\//, '')
			// URL encode filePath
			filePath = encodeURIComponent(filePath)
			const url = config.url.API_URL + '/download?path=' + filePath
			// download the file
			window.open(url, '_blank')
			setLoading(false)
    }
	}

	const emptyMessage = () => {
		return (
			<div>
				{
					// if w permission is present, show upload box
					currentDirObject.permissions?.includes('w') &&
					<div className='w-full text-center py-10'>
						<div onClick={() => fileUploadRef.current.getInput().click() }
						className='w-auto
						bg-gradient-to-b from-slate-600/40 to-slate-600/70
						hover:from-slate-600/70 hover:to-slate-500/10
						mx-10 mb-10 pt-7 pb-9 cursor-pointer
						text-slate-300 hover:text-white font-light
						rounded-2xl hidden md:block'>
							<BsCloudArrowUp size={150} className={"m-auto"} />
							<span>Drag and drop files here</span>
						</div>
						<div
							className="relative w-64 mx-auto cursor-pointer
							rounded-xl
							bg-gradient-to-b from-lime-500/80 to-lime-600/80
							hover:from-lime-400/80 hover:to-lime-600/80
							shadow-xl shadow-slate-800/30
							px-8 py-4"
							onClick={() => fileUploadRef.current.getInput().click() }
						>
							Choose files to upload
						</div>
					</div>
				}
				{
					// if r permission is present, show empty message
					currentDirObject.permissions?.includes('r') &&
					<div className='w-full py-10 text-slate-400 text-center'>
						<BsFolder size={50} className='m-auto mb-2' />
						<h1>Empty directory</h1>
					</div>
				}
			</div>
		);

	}

	const downloadFolder = () => {
		if (loading)
			return false

		// if current directory has not 'r' permission, toast the error
		if (!currentDirObject.permissions.includes('r')) {
			toast.current.show({severity: 'error', summary: 'Permission denied', detail: 'You do not have permission download this folder', life: 3000});
			return
		}
		let folderPath = currentDirObject.path
		// replace any duplicated / to a single /
		folderPath = folderPath.replace(/\/+/g, '/')
		// replace starting slash
		folderPath = folderPath.replace(/^\//, '')
		// URL encode folderPath
		folderPath = encodeURIComponent(folderPath)
		// folderPath = btoa(folderPath)
		const url = config.url.API_URL + '/download_folder?path=' + folderPath

		// Check if there is enough space to download the folder
		const url_check = url + '&check=true'
		// Fetch the url_check, if return code is 200, download the file, if its 400, toast the error
		fetch(url_check)
			.then((response) => {
				if (response.status === 200) {
					// download the file
					window.open(url, '_blank')
				}
				else {
					toast.current.show({severity: 'error', summary: 'Error', detail: 'No space left on device', life: 3000});
				}
			})
	}

	useEffect(() => {
		// Load nodes data
		getTreeData()
	}, []);

	return (
		<div className="relative w-full shadow-2xl shadow-slate-900/40">
			<div className='flex w-full h-[7vh] pl-6 pr-7 space-x-6 md:space-x-8
			bg-gradient-to-b from-slate-700/20 to-slate-700'>

				{
					currentDirObject.path === '/' ?
					<FaHome
						className="text-2xl select-none text-white m-auto cursor-default"
					/>
					:
					<>
						<Tooltip target={".button-back"} />
						<FaArrowLeft
							data-pr-tooltip="Go back"
							data-pr-position="bottom"
							data-pr-showdelay="1000"
							className={"text-2xl select-none m-auto cursor-pointer button-back" + (loading ? " cursor-auto" : "")}
							onClick={() => getTreeData(currentDirObject.parent_path)}
						/>
					</>
				}
				<div className={"flex m-auto"}>
					<span className={"m-auto text-white text-base md:text-lg font-medium"}>{currentDirObject.path}</span>
				</div>

				<div className={"flex flex-grow"}>
				</div>

				{/*Upload button should be shown if current directory has 'w' permission*/}
				{currentDirObject.permissions?.includes('w') &&
				<>
					<Tooltip target={".button-upload"} />
					<FaUpload
						data-pr-tooltip="Upload files"
						data-pr-position="bottom"
						data-pr-showdelay="1000"
						className='text-2xl mt-5 md:mt-6 text-lime-300 cursor-pointer button-upload'
						onClick={() => { fileUploadRef.current.getInput().click() } }
					/>
					<div className='border-r border-slate-600'></div>
				</>
				}

				<Tooltip target={".download-folder"} />
				<FaDownload
					data-pr-tooltip="Download dir as ZIP"
					data-pr-position="bottom"
					data-pr-showdelay="1000"
					className={'text-2xl mt-5 md:mt-6 cursor-pointer download-folder'  + (loading ? " cursor-auto" : "")}
					onClick={downloadFolder}
				/>
			</div>

			<div className='md:rounded-bl-2xl md:rounded-br-2xl md:overflow-hidden
				bg-gradient-to-r from-slate-700/80 to-slate-700/50
			'>
				<Tooltip target={".copy-path"} />
				<DataTable
					value={treeData}
					emptyMessage={emptyMessage}
					onRowClick={handleRowClick}
					loading={loading}
					loadingIcon={<CgSpinner size={40} className={"animate-spin"} />}
					virtualScrollerOptions={{ itemSize: 50, autoSize: true}}
					resizableColumns
					removableSort
					scrollable
					scrollHeight="79.3vh"
					selectionMode="single"
				>
					<Column field={"data.name"} header="Name " body={nameTemplate} sortable style={{ width: '80%' }}></Column>
					<Column field={"data.size_bytes"} header="Size " body={sizeTemplate} hidden={false} sortable style={{ width: '20%' }}></Column>
				</DataTable>
			</div>

		</div>
	)
}
