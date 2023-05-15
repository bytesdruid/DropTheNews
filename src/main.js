import Web3 from 'web3';
import { newKitFromWeb3 } from '@celo/contractkit';
import BigNumber from 'bignumber.js';
import dropTheNewsAbi from '../contract/dropTheNews.abi.json';
import erc20Abi from "../contract/erc20.abi.json"

const ERC20_DECIMALS = 18;
const ContractAddress = "0x6F5cD0Aed902F1A56D24FE5deB9e1635beA8C783";
const cUSDContractAddress = "0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1";

let kit;
let contract;

let postednews = [];
let nftData = {};



const connectCeloWallet = async function () {
    if (window.celo) {
        try {
            notification("⚠️ Please approve this DApp to use it.")
            await window.celo.enable()
            notificationOff()

            const web3 = new Web3(window.celo)
            kit = newKitFromWeb3(web3)

            const accounts = await kit.web3.eth.getAccounts()
            kit.defaultAccount = accounts[0]

            contract = new kit.web3.eth.Contract(dropTheNewsAbi, ContractAddress)
        } catch (error) {
            notification(`${error}.`)
        }
    } else {
        notification("Please install the CeloExtensionWallet.")
    }
}

async function approve(_price) {
    const cUSDContract = new kit.web3.eth.Contract(erc20Abi, cUSDContractAddress)

    const result = await cUSDContract.methods
        .approve(ContractAddress, _price)
        .send({ from: kit.defaultAccount })
    return result
}

const getBalance = async function () {
    const totalBalance = await kit.getTotalBalance(kit.defaultAccount)
    const cUSDBalance = totalBalance.cUSD.shiftedBy(-ERC20_DECIMALS).toFixed(2)
    document.querySelector("#balance").textContent = cUSDBalance
}

function notification(_text) {
    document.querySelector(".alert").style.display = "block"
    document.querySelector("#notification").textContent = _text
}

function notificationOff() {
    document.querySelector(".alert").style.display = "none"
}

// Add news 
document.querySelector("#newsBtn").addEventListener("click", async (e) => {
    const title = document.getElementById("newsTitle").value;
    const description = document.getElementById("newsDescription").value;
    
    notification(`Adding "${title}"...`)
    try {
        await contract.methods
        .postNews(title, description)
        .send({ from: kit.defaultAccount })
    } catch (error) {
        notification(`⚠️ ${error}.`)
    }
    notification(`You have successfully added "${title}".`)
    // Get the news
    getNews();

});

// Get news
const getNews = async function () {
    const newsLength = await contract.methods.getNewsLength().call()
    const _postednews = []

    for (let i = 0; i < newsLength; i++) {
        let n = new Promise(async (resolve, reject) => {
            let _news = await contract.methods.getNews(i).call()
            resolve({
                index: i,
                owner: _news[0],
                title: _news[1],
                description: _news[2],
                likes: new BigNumber(_news[3]),
                tips: new BigNumber(_news[4])
            })
        })
        _postednews.push(n)
    }
    postednews = await Promise.all(_postednews);

    // Render the news
    renderNews();
}




function renderNews() {
    // Get the news section ready to display all the news;
    document.getElementById("news-section").innerHTML = "";
    postednews.forEach((news) => {
        if (news["title"].length) {
            // Append html to the news section
            document.getElementById("news-section").innerHTML += newsTemplate(news);

        }
    })
    notificationOff();
}

function newsTemplate(news) {
    return `
        <div class="card mb-4" style="min-height: 50px">
        <div class="card-body text-left p-4 position-relative">
            <div class="translate-middle-y position-absolute top-0">
            ${identiconTemplate(news.owner)}
            </div>
            <h2 class="card-title fs-4 fw-bold mt-2">${news.title}</h2>
            <p class="card-text mt-2 mb-2">${news.description}</p>
            <p class="card-text mb-2">
                <strong>Likes</strong>: ${news.likes} Likes
            </p>
            <p class="card-text mb-2">
                <strong>Tips</strong>: 
                ${
                    new BigNumber(news.tips)
                    .shiftedBy(-ERC20_DECIMALS)
                    .toString()
                } Cusd
            </p>
            </br>
            <div class="d-grid gap-2">
                <a class="btn btn-lg btn-outline-dark likeBtn fs-6 p-3" id=${news.index}>
                    <img src="https://static-00.iconduck.com/assets.00/white-heart-emoji-512x502-vkzcruk0.png" width="15px"/>
                </a>
                <a class="btn btn-lg btn-outline-dark tipBtn fs-6 p-3" id=${news.index}>Tip</a>
            </div>
        </div>
        </div>
    `
}

function identiconTemplate(_address) {
    const icon = blockies
        .create({
            seed: _address,
            size: 8,
            scale: 16,
        })
        .toDataURL()

    return `
        <div class="rounded-circle overflow-hidden d-inline-block border border-white border-2 shadow-sm m-0">
            <a href="https://alfajores-blockscout.celo-testnet.org/address/${_address}/transactions"
                target="_blank">
                <img src="${icon}" width="48" alt="${_address}">
            </a>
        </div>
    `
}



document.querySelector("#btn-add-news").addEventListener("click", function(e) {
    jQuery('#addNewsModal').modal('toggle')
})

document.querySelector("#myNewsPage").addEventListener("click", function(e) {

    // hide the news section and unhide the nft section
    jQuery("#news-section").css({"display": "block"});
    jQuery("#myNFT-section").css({"display": "none"});
})

document.querySelector("#myNFTPage").addEventListener("click", function(e) {

    // hide the news section and unhide the nft section
    jQuery("#news-section").css({"display": "none"});
    jQuery("#myNFT-section").css({"display": "block"});
})

document.querySelector("#news-section").addEventListener("click", async (e) => {
    if(e.target.className.includes("likeBtn")) {
        
        let id = e.target.id;

        notification(`⌛ Awaiting Liking or Disliking ..."`)
        try {
            await contract.methods
            .likeAndDislikeNews(id)
            .send({ from: kit.defaultAccount })
        } catch (error) {
            notification(`⚠️ ${error}.`)
        }

        // Get the news  
        getNews();

        
    }

    if(e.target.className.includes("tipBtn")) {
        
        let id = e.target.id
        // toggle modal
        jQuery('#tipModal').modal('toggle')
        // get the value from the modal
        document.querySelector('#tipBtn').addEventListener("click", async (e) => {
            e.preventDefault();
            let tipAmount = new BigNumber(document.getElementById("tipAmount").value)
            .shiftedBy(ERC20_DECIMALS)
            .toString()



            // call contract method

            notification("Waiting for payment approval...")
            try {
                await approve(tipAmount)
            } catch (error) {
                notification(`${error}.`)
            }
            notification(`Awaiting Tipping ...`)
            try {
                await contract.methods
                .tipCreator(id, tipAmount)
                .send({ from: kit.defaultAccount })
            } catch (error) {
                notification(`⚠️ ${error}.`)
            }

            notification(`You have successfully tipped news creator.`)
            // Get the balance and news
            getBalance();    
            getNews();


        })
        
    }
})

async function renderClaimedNFT() {
    // append nft information in appriopriate place
    if(nftData.id) {
        let a = await fetch(nftData.uri);
        let b = await a.json();
        let name = b["name"]
        let description = b["description"]
        let image = b["image"]

        document.querySelector("#myNFT-section").innerHTML = `

        <div class="card mt-4" style="width: 18rem;">
            <img class="card-img-top" src=${image} alt="Card image cap">
            <div class="card-body">
                <p class="card-text">${name} #${nftData.id}</p>
                <p class="card-text">${description}</p>
            </div>
        </div>
        `

    }
}

const getClaimedNFT = async() => {

    const claimedNFT = await contract.methods.getClaimedNFT().call();
    // Get claimed nft 
    nftData.id = claimedNFT[0];
    nftData.uri = claimedNFT[1];

    renderClaimedNFT();

}

document.querySelector("#myNFT-section").addEventListener("click", async (e) => {
    if(e.target.className.includes("btn-claim")) {


        notification(`Claiming NFT ...`)
        // CLAIM NFT
        // Link to metadata hash
        const metadatahash = ("https://gateway.pinata.cloud/ipfs/QmTm9gokrJsHY8PWRUbHmCBdULUoaQZsgiqRWoLjEiwR1K");
        try {
            await contract.methods
            .claimNFT(metadatahash)
            .send({ from: kit.defaultAccount })
            notificationOff()
        } catch (error) {
            notification(`${error}.`)
        }
        setTimeout(() => {notificationOff()}, 3000);
        getClaimedNFT()

    }

})


window.addEventListener("load", async () => {
    notification("Loading...")
    await connectCeloWallet()
    await getBalance()
    await getNews()
    await getClaimedNFT()
    notificationOff()
})