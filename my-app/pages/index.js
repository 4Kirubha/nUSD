import Head from "next/head";
import {providers,Contract,utils, BigNumber} from "ethers";
import Web3Modal from "web3modal";
import React,{ useEffect,useState,useRef} from "react";
import styles from "../styles/Home.module.css";
import { NUSD_ADDRESS,NUSD_MAIN_ADDRESS,NUSD_ABI,NUSD_MAIN_ABI} from "../constants/index";

export default function Home(){
  const zero = BigNumber.from(0);
  const[walletConnected,setWalletConnected] = useState(false);
  const[amountEth,setAmountEth] = useState(zero);
  const[totalNUSD,setTotalNUSD] = useState(zero);
  const[loading,setLoading] = useState(false);
  const[isOwner,setIsOwner] = useState(false);
  const web3ModalRef = useRef();

    const getSignerOrProvider = async(needSigner = false) => {
      const provider = await  web3ModalRef.current.connect();
      const web3Provider = new providers.Web3Provider(provider);

      const {chainId} = await web3Provider.getNetwork();

      if(chainId != 11155111){
        window.alert("Change the network to Sepolia");
        throw new Error("Change network to Sepolia");
      }
      if(needSigner){
        const signer = web3Provider.getSigner();
        return signer;
      }
      return web3Provider;
    };

    async function depositEth(){
      try{
        const signer = await getSignerOrProvider(true);
        const nusdContract = new Contract(NUSD_MAIN_ADDRESS,NUSD_MAIN_ABI,signer);
        const tx = await nusdContract.depositEthAndMint({value: utils.parseEther(amountEth.toString())})
        setLoading(true);
        await tx.wait();
        await totalSupply()
        setLoading(false);
      }catch(err){
        console.error(err.message);
      }
    }

    async function redeemEth(){
      try{
        const signer = await getSignerOrProvider(true);
        const nusdToken = new Contract(NUSD_ADDRESS,NUSD_ABI,signer);
        const nusdContract = new Contract(NUSD_MAIN_ADDRESS,NUSD_MAIN_ABI,signer);
        const amountToMint = await nusdContract._calculateAmountToBurn(amountEth);
        const approveTx = await nusdToken.approve(NUSD_MAIN_ADDRESS,amountToMint);
        await approveTx.wait();
        setLoading(true);
        const tx = await nusdContract.redeemEthForNusd(amountEth)
        await tx.wait();
        setLoading(false);
        await totalSupply();       
      }catch(err){
        console.error(err.message);
      }
    }

    async function totalSupply(){
      try{
        const provider = await getSignerOrProvider();
        const nusdToken = new Contract(NUSD_ADDRESS,NUSD_ABI,provider);
        const totalNusd = await nusdToken.totalSupply();
        setTotalNUSD(totalNusd)
      }catch(err){
        console.error(err.message);
      }
    }

    async function connectWallet(){
      try{
        await getSignerOrProvider();
        setWalletConnected(true);
      }catch(err){
        console.error(err);
      }
    }

    // async function getOwner(){
    //   try{
    //     const provider = await getSignerOrProvider();
    //     const nftContract = new Contract(NUSD_MAIN_ADDRESS,NUSD_ABI,provider);
    //     const _owner = await nftContract.owner();
  
    //     const signer = await getSignerOrProvider(true);
    //     const address = await signer.getAddress();
    //     if(address.toLowerCase() === _owner.toLowerCase()){
    //       setIsOwner(true);
    //     }
    //   }catch(err){
    //   console.error(err.message);
    //   }
    // }

    useEffect(() =>{
      if(!walletConnected){
        web3ModalRef.current = new Web3Modal({
          network:"sepolia",
          providerOptions:{},
          disableInjectedProvider: false,
        });
        connectWallet();
        totalSupply();
      }
    },[walletConnected])

    function renderButton(){
      if(!walletConnected){
        return (<button onClick={connectWallet} className={styles.button}>Connect your wallet</button>);
      }
      if(loading){
        return (<button className={styles.button}>Loading...</button>);
      }return(
      <div>
            <input
              type="number"
              placeholder="Enter ETH Amount"
              className={styles.input}
              onChange={(e) => setAmountEth(BigNumber.from((e.target.value).toString()))}>
            </input>
            <button className={styles.button} onClick={depositEth}>DEPOSIT</button>
            <button className={styles.button} onClick={redeemEth}>REDEEM</button>
            <div>{utils.formatEther(totalNUSD)}</div>
      </div>)
    }

   return (
      <div>
        <Head>
          <title>Krypto Koin</title>
          <meta name="description" content="Whitelist-Dapp" />
          <link rel="icon" href="/favicon.ico" />
        </Head>
        <div className={styles.main}>
          <div>
            <h1 className={styles.title}></h1>
            <div className={styles.description}>
            </div>
            <div className={styles.description}>
            </div>
            {renderButton()}
          </div>
          <div>
          </div>
        </div>
  
        <footer className={styles.footer}>        </footer>
      </div>
    );
  }