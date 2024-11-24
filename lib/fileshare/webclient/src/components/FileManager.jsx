import {useEffect, useRef, useState} from 'react';
import { Toast } from 'primereact/toast';
import { FileUpload } from 'primereact/fileupload';
import { ProgressBar } from 'primereact/progressbar';
import { Tooltip } from 'primereact/tooltip';
import { FileList } from './FileList.jsx';
import { FaHardDrive } from "react-icons/fa6";
import { getIconForFile } from "vscode-icons-js";
import { config } from "../constants.js";



export const FileManager = (props) => {
	const toast = useRef(null);
	const [currentDir, setCurrentDir] = useState({
		parent_path: "/",
		path: "/",
		permissions: "rx",
		size: "0 GB",
		total_file_count: 0
	});
	const [totalSize, setTotalSize] = useState(0);
	const [diskInfo, setDiskInfo] = useState([]);
	const [uploadDisabled, setUploadDisabled] = useState(false);
	const fileUploadRef = useRef(null);
	const uploadUrl = config.url.API_URL + '/upload_files';
	const [uploadProgressValue, setUploadProgressValue] = useState(0);

	const cancelUpload = (options) => {
		fileUploadRef.current.clear();
		setUploadProgressValue(0);
	}

	const progressBarTemplate = (options) => {
		return (
			<div className="flex px-5 pt-5 pb-3 w-full bg-gradient-to-b from-slate-700/20 to-slate-700">
				<Tooltip target={".cancel-upload"} />
				<div className={"flex flex-col flex-grow pb-[10px]"}>
					<div className={"flex text-xs mb-1"}>
						<span className={"flex-grow animate-pulse"}>Uploading files</span>
						<span>{uploadProgressValue}%</span>
					</div>
					<ProgressBar value={uploadProgressValue} showValue={false} className={"flex-grow my-auto h-[8px] z-10"}></ProgressBar>
				</div>
				{/*Cancel button*/}
				{/*<div*/}
				{/*	className={"pl-[15px] text-slate-300/70 hover:text-white cursor-pointer overflow-hidden h-full cancel-upload"}*/}
				{/*	onClick={() => { cancelUpload(options) }}*/}
				{/*	data-pr-tooltip={"Cancel"}*/}
				{/*	data-pr-position={"bottom"}*/}
				{/*	data-pr-showdelay={"1000"}*/}
				{/*>*/}
				{/*	<MdCancel className={"mt-[15px]"} />*/}
				{/*</div>*/}
			</div>
		);
	}

	const onProgress = (e) => {
		setUploadProgressValue(e.progress)
	}

	const getFilenameToGetIconFile = (filename) => {
		// remove all dots from filename but keep dot for extension
		// example: name.with.dots.txt => name_with_dots.txt

		// get extension
		const extension = filename.split('.').pop();
		// get filename without extension
		const name = filename.substring(0, filename.lastIndexOf('.'));
		// replace all dots with underscore
		const nameWithoutDots = name.replace(/\./g, '_');
		// join name with extension
		const filenameWithoutDots = nameWithoutDots + '.' + extension;

		return filenameWithoutDots;
	}

	const onTemplateSelect = (e) => {
		let _totalSize = totalSize;
		let files = e.files;

		Object.keys(files).forEach((key) => {
			_totalSize += files[key].size || 0;
		});

		setTotalSize(_totalSize);
	};

	const onTemplateUpload = (e) => {
		let _totalSize = 0;

		e.files.forEach((file) => {
			_totalSize += file.size || 0;
		});

		setTotalSize(_totalSize);
		toast.current.show({
			severity: 'info',
			summary: 'Upload completed',
			detail: 'Files uploaded successfully',
			sticky: true
		});
		setUploadProgressValue(0);
		setTimeout(() => {
			fileUploadRef.current.clear();
		}, 100);
	};

	const onTemplateRemove = (file, callback) => {
		setTotalSize(totalSize - file.size);
		callback();
	};

	const onTemplateClear = () => {
		setTotalSize(0);
	};

	useEffect(() => {
		// Check permissions, if w is present, enable upload
		if (currentDir.permissions.includes('w')) {
			setUploadDisabled(false);
		} else {
			setUploadDisabled(true);
		}
	}, [currentDir]);

	const headerTemplate = (options) => {
		const { className, chooseButton, uploadButton, cancelButton } = options;

		// get % of data.disk.used and data.disk.total to show in progress bar.
		const value = diskInfo?.used?.value && diskInfo?.total?.value ? (diskInfo.used.value / diskInfo.total.value) * 100 : 0;
		const formatedValue = fileUploadRef && fileUploadRef.current ? fileUploadRef.current.formatSize(totalSize) : '0 B';

		return (
			<div className='relative w-full px-6 h-[7vh]
			grid gap-6 grid-cols-[30px_1fr_auto] content-center'>

				{ /* NOTE: This div is needed to call the functions for uploading */ }
				<div className='hidden'>
					{uploadButton}
					{chooseButton}
					{cancelButton}
				</div>

				<img src='/assets/torbox-icon-300x300.png' alt='TorBox' className='' />
				<div className='text-xl font-bold md:font-light mt-[2px]'>
					<span className='font-bold pr-2 hidden md:inline-block'>TorBox</span> File Share
				</div>

				<div className="">
					{(diskInfo.used) &&
						<div className={"flex items-center pt-0.5"}>
							<FaHardDrive className='text-[1.6rem] pt-0.5' />
							<div className={"flex flex-col pl-3"}>
								<span className='text-xs font-light pb-1'>
									<span className='text-lime-300'>{diskInfo.used.text}</span>
									<span className='mx-1.5'>of</span>
									<span className='font-light'>{diskInfo.total.text}</span>
								</span>
								<ProgressBar value={value} showValue={false} style={{ width: '8.8rem', height: '4px' }}></ProgressBar>
							</div>
						</div>
					}
				</div>

			</div>
		);
	};

	const itemTemplate = (data, props) => {
		const _filename = getFilenameToGetIconFile(data.name);
		const icon = getIconForFile(_filename);

		return (
			<div className="grid gap-5 md:gap-8 grid-cols-[30px_1fr_90px_20px] px-8
			bg-gradient-to-b from-slate-700/60 to-slate-700
			text-sm md:text-base">
				<img src={'/icons/' + icon} alt="file" width="30" />
				<div className='text-left text-slate-200 font-normal pt-0.5'>
					{data.name}
				</div>
				<div className='pt-0.5 font-light text-slate-300/70'>{props.formatSize}</div>
			</div>
		);
	};

	const emptyTemplate = (options) => {
		return (
			<div className="flex w-full h-full align-items-center overflow-hidden">
				<FileList {...{currentDir, setCurrentDir, toast, fileUploadRef}} />
			</div>
		);
	};

	const getInfo = () => {
		// fetch get_disk_info
		fetch(config.url.API_URL + '/get_disk_info')
			.then((response) => response.json())
			.then((data) => {
				setDiskInfo(data);
			});
	}

	useEffect(() => {
		getInfo();

		return () => {
			setDiskInfo([]);
		}
	}, []);

	return (
		<div className={"w-full md:max-w-4xl mx-auto"}>
			<Toast position='top-center' ref={toast}></Toast>

			<FileUpload
				auto={true}
				style={{ width: '100%' }}
				ref={fileUploadRef}
				name="files[]"
				url={uploadUrl+"?path="+currentDir.path}
				disabled={uploadDisabled}
				multiple
				accept="*/*"
				maxFileSize={1024000000}
				onUpload={onTemplateUpload}
				onSelect={onTemplateSelect}
				onError={onTemplateClear}
				onClear={onTemplateClear}
				onProgress={onProgress}
				headerTemplate={headerTemplate}
				itemTemplate={itemTemplate}
				emptyTemplate={emptyTemplate}
				progressBarTemplate={progressBarTemplate}
			/>

			<div className='w-full pt-5 md:pt-6
			text-center text-sm text-slate-500 font-light'>
				TorBox <span className='font-bold pr-3'>File Share v2.0</span>
			</div>

		</div>
	)
}
