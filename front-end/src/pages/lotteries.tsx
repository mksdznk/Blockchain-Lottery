import { ConnectButton } from '@rainbow-me/rainbowkit';
import { 
  useAccount, 
  useReadContract, 
  useReadContracts, 
  useWriteContract, 
  useBalance, 
  useWaitForTransactionReceipt 
} from 'wagmi'
import type { NextPage } from 'next';
import Head from 'next/head';
import styles from '../styles/Home.module.css';
import { useRouter } from 'next/router';
import { 
  useEffect, 
  useMemo, 
  useState 
} from 'react';
import { lotteryFactoryContractConfig } from '../contracts/lotteryFactoryContractConfig';
import { lotteryNftContractConfig } from 'src/contracts/lotteryNftContractConfig';
import { Button } from '@/components/ui/button';
import { 
  Card,
  CardContent,
  CardFooter,
  CardHeader,
  CardTitle
} from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import NftImage from 'public/images/mystery-nft.png';
import GitHubImage from 'public/images/GitHub_Lockup_Black.svg'
import Image from 'next/image';
import { 
  Popover,
  PopoverTrigger, 
  PopoverContent, 
  PopoverHeader, 
  PopoverDescription 
} from '@/components/ui/popover';
import { Separator } from '@/components/ui/separator';
import { toast } from 'sonner';
import { lotteryContractConfig } from 'src/contracts/lotteryContractConfig';

const Lotteries: NextPage = () => {
    const { isConnected, address: user, chainId} = useAccount();
    const router = useRouter();

    type Lottery = {
      id: bigint;
      lotteryAddress: string;
      fee: bigint;
      price: bigint;
      winner: string;
      winningAmount: bigint;
    }

    useEffect(() => {
    if (!isConnected) {
        router.push('/');
    }
    }, [isConnected, router]);

    const [ticketsToBuy, setTicketsToBuy] = useState(0);
    const [ticketsToTransfer, setTicketsToTransfer] = useState(0);
    const [addressToTransfer, setAddressToTransfer] = useState("0x0");

    const { data: owner} = useReadContract({
      ...lotteryFactoryContractConfig,
      functionName: 'owner',
      args: [],
    });

    const { data: lotteryCount} = useReadContract({
      ...lotteryFactoryContractConfig,
      functionName: 'getLotteryCount',
      args: [],
    }); 

    const count = Number(lotteryCount ?? 0);

    const lotteryCalls = useMemo(() =>
      Array.from({length: count}, (_, i) => ({
        ...lotteryFactoryContractConfig,
        functionName: 'getLotteryWithId',
        args: [BigInt(i)]
      })),
      [count]
    );

    const { data: lotteriesData, isLoading: loadingLotteries} = useReadContracts({
      contracts: lotteryCalls as any,
    })

    const pastLotteries: Lottery[] = useMemo(() => {
      if (!lotteriesData) return [];
      return lotteriesData
        .filter(item => item.status === 'success' && item.result != null)
        .map(item => item.result as Lottery);
    }, [lotteriesData]);
    
    const pastLotteriesWithNft = useMemo(() =>
      pastLotteries.filter(l => Number(l.id) < 5),
      [pastLotteries]
    );
    
    const nftCalls = useMemo(() =>
      pastLotteriesWithNft.map(l => ({
        ...lotteryNftContractConfig,
        functionName: 'tokenURI',
        args: [l.id]
      })),
      [pastLotteriesWithNft]
    );

    const { data: tokenURIsData } = useReadContracts({ contracts: nftCalls as any });
    
    const [nftImages, setNftImages] = useState<Record<number, string>>({});
    
    useEffect(() => {
      if (!tokenURIsData) return;
      tokenURIsData.forEach((item, index) => {
        if (item.status !== 'success' || !item.result) return;
        const lotteryId = Number(pastLotteriesWithNft[index].id);
        const metadataUrl = String(item.result).replace('ipfs://', 'https://violet-far-crab-781.mypinata.cloud/ipfs/');
        fetch(metadataUrl)
          .then(res => res.json())
          .then(metadata => {
            const imageUrl = String(metadata.image).replace('ipfs://', 'https://violet-far-crab-781.mypinata.cloud/ipfs/');
            setNftImages(prev => ({ ...prev, [lotteryId]: imageUrl }));
          })
          .catch(console.error);
      });
    }, [tokenURIsData]);
    
    const { data: activeLottery} = useReadContract({
      ...lotteryFactoryContractConfig,
      functionName: 'getActiveLottery',
      args: [],
    });
    
    const lotteryAddress = activeLottery !== null || activeLottery !== undefined ? String(activeLottery) : null;
    
    const {data: prizePoolSize} = useBalance({
      address: lotteryAddress as `0x{string}`,
      query: {
        enabled: activeLottery !== null || activeLottery !== undefined,
      }
    });

    const {data: userTickets} = useBalance({
      address: user,
      token: lotteryAddress as `0x{string}`,
    });

    const { data: feePercentage } = useReadContract({
      address: lotteryAddress as `0x{string}`,
      abi: lotteryContractConfig.abi,
      functionName: 'getFeePercentage',
      args: [],
      query: {
        enabled: activeLottery !== null || activeLottery !== undefined,
      },
    });
    
    const { data: maxTickets } = useReadContract({
      address: lotteryAddress as `0x{string}`,
      abi: lotteryContractConfig.abi,
      functionName: 'cap',
      args: [],
      query: {
        enabled: activeLottery !== null || activeLottery !== undefined,
      },
    });
    
    const { data: ticketsLeft } = useReadContract({
      address: lotteryAddress as `0x{string}`,
      abi: lotteryContractConfig.abi,
      functionName: 'getTicketsLeft',
      args: [],
      query: {
        enabled: activeLottery !== null || activeLottery !== undefined,
      },
    });
    
    const { data: ticketPriceInWei } = useReadContract({
      address: lotteryAddress as `0x{string}`,
      abi: lotteryContractConfig.abi,
      functionName: 'getTicketPriceInWei',
      args: [],
      query: {
        enabled: activeLottery !== null || activeLottery !== undefined,
      },
    });
    
    const { data: numberOfOwners } = useReadContract({
      address: lotteryAddress as `0x{string}`,
      abi: lotteryContractConfig.abi,
      functionName: 'getNumberOfOwners',
      args: [],
      query: {
        enabled: activeLottery !== null || activeLottery !== undefined,
      },
    });

    const { data: maxOwners } = useReadContract({
      address: lotteryAddress as `0x{string}`,
      abi: lotteryContractConfig.abi,
      functionName: 'getMaxOwners',
      args: [],
      query: {
        enabled: activeLottery !== null || activeLottery !== undefined,
      },
    });

    const {
      data: buyTicketsHash,
      isPending: isBuying,
      writeContract: buyTicketsWriteContract,
    } = useWriteContract();

    const { 
      isLoading: isBuyingLoading,
      isSuccess: isBuyingSuccess,
      isError: isBuyingError,
    } = useWaitForTransactionReceipt({
      hash: buyTicketsHash,
    });

    const {
      data: transferTicketsHash,
      isPending: isTransfering,
      writeContract: transferTicketsWriteContract,
    } = useWriteContract();

    const { 
      isLoading: isTransferingLoading,
      isSuccess: isTransferingSuccess,
      isError: isTransferingError,
    } = useWaitForTransactionReceipt({
      hash: transferTicketsHash,
    });
    
    function buyTickets() {
        buyTicketsWriteContract({
          address: lotteryAddress as `0x{string}`,
          abi: lotteryContractConfig.abi,
          functionName: 'purchaseTickets',
          value: BigInt(ticketsToBuy * Number(ticketPriceInWei)),
          args: [],
        });
    }

    function transferTickets() {
      transferTicketsWriteContract({
        address: lotteryAddress as `0x{string}`,
        abi: lotteryContractConfig.abi,
        functionName: 'transferTickets',
        args: [addressToTransfer, BigInt(ticketsToTransfer)],
      });
    }

    function copyLotteryAddress(lotteryAddress: string) {
      navigator.clipboard.writeText(lotteryAddress);
      toast.success("Address copied to clipboard", {position: 'top-center'});
    }

    function lotteryEtherscanLink(lotteryAddress: string) {
      if (chainId === 1) {
        return `https://etherscan.io/address/${lotteryAddress}`
      }
      else if (chainId === 11155111) {
        return `https://sepolia.etherscan.io/address/${lotteryAddress}`
      }
    }

    useEffect(() => {
      if (isBuyingSuccess) {
        toast.success('Successfully bought ticket/s', {position: 'top-center'});
      }

      if (isBuyingError) {
        toast.error('Error buying ticket/s', {position: 'top-center'});
      }

      if (isTransferingSuccess) {
        toast.success('Successfully sent ticket/s', {position: 'top-center'});
      }

      if (isTransferingError) {
        toast.error('Error sending ticket/s', {position: 'top-center'});
      }

    })

  return (
    <div className={styles.container}>
      <Head>
        <title>Blockchain Lottery</title>
        <meta
          content="Generated by @rainbow-me/create-rainbowkit"
          name="description"
        />
        <link href='/images/eth-icon.ico' type='image/x-icon' rel="icon" />
      </Head>

      <header className="flex justify-end">
        <div className='pt-2'>
          <ConnectButton />
        </div>
      </header>

        <main className="flex flex-col">
        <div className='flex justify-start m-3'>
          <h1 className='text-5xl p-3'>
            Blockchain Lotteries {/* add etherscan link of contract */}
          </h1>
          <div className='pt-5'>
            { owner == user && <Button onClick={() => router.push('/admin-panel')}>Go to admin panel</Button> }
          </div>
        </div>

        <div className='grid grid-cols-3'>
          {activeLottery == 0 &&
          <Card className='m-4 flex flex-col'>
            <CardHeader>
              <CardTitle className='mt-1 mr-1'>No active lottery</CardTitle>
            </CardHeader>
          </Card>
          }
          {activeLottery != 0 &&
          <Card className='m-4 flex flex-col'>
            <CardHeader>
              <div className='flex'>
                <CardTitle className='mt-1 mr-1'>Lottery id: {Number(lotteryCount) - 1} </CardTitle>
                <Badge className='bg-green-400 mt-0'>Active</Badge>
              </div>
              <CardTitle>
                Lottery address:  
                <a href={lotteryEtherscanLink(String(activeLottery))}>
                  { ' ' + String(activeLottery).slice(0, 6) + "..." + String(activeLottery).slice(38) } 
                </a>  
                <Button 
                  className="h-6 w-12 m-2" 
                  onClick={() => copyLotteryAddress(String(activeLottery))}>
                    copy
                </Button> 
              </CardTitle>
              <Popover>
                <PopoverTrigger asChild>
                  <Button className='w-min'variant="outline">More Info</Button>
                </PopoverTrigger>
                <PopoverContent>
                  <PopoverHeader>
                    <PopoverDescription>
                      Ticket price: {Number(ticketPriceInWei)} Wei | {Number(ticketPriceInWei) / 10 ** 18} ETH
                    </PopoverDescription>
                    <PopoverDescription>
                      Prize pool size: {Number(prizePoolSize?.value)} Wei | {Number(prizePoolSize?.formatted)} ETH
                    </PopoverDescription>
                    <PopoverDescription>
                      Tickets left: {Number(ticketsLeft)} / {Number(maxTickets)}
                    </PopoverDescription>
                    <PopoverDescription>
                      Number of owners: {Number(numberOfOwners)} / {Number(maxOwners)}
                    </PopoverDescription>
                    <PopoverDescription>
                      Fee percentage: { Number(feePercentage) / 100 } %
                    </PopoverDescription>       
                  </PopoverHeader>
                </PopoverContent>
              </Popover>
            </CardHeader>
            <CardContent>
              <Image src={NftImage} alt="img" className="object-center" width={350} height={350} />
            </CardContent>
            <CardFooter className='flex flex-col'>
                  <code> {Number(userTickets?.value) > 0 ? "You have " + Number(userTickets?.value) + " tickets" : ""} </code>
                  <Button 
                    className='w-full'
                    disabled={Number(ticketsLeft) == 0 || Number(ticketsLeft) > ticketsToBuy || ticketsToBuy == 0 || isBuying || isBuyingLoading}
                    onClick={buyTickets}>
                      {isBuying || isBuyingLoading? 'Buying...' :  'Buy ticket / s'}
                  </Button>
                  <div className='w-full flex flex-row'>
                    <Input 
                      className='w-1/3'
                      type="number" 
                      step={1} 
                      min={1} 
                      placeholder="Number of tickets" 
                      onChange={(e) => setTicketsToBuy(Number(e.target.value))} />
                    <code className='p-2'>
                      = {Number(ticketPriceInWei) * ticketsToBuy} Wei | {Number(ticketPriceInWei) * ticketsToBuy / 10 ** 18} ETH
                    </code>
                  </div>
                
            </CardFooter>
          </Card>
          }
          {activeLottery != 0 &&
          <Card className='m-4 flex flex-col'>
            <CardHeader>
              <CardTitle className='mt-1 mr-1'>Transfer tickets: </CardTitle>
            </CardHeader>
            <CardContent>
              <Input
                className="m-2"
                type="number" 
                step={1} 
                min={1} 
                placeholder="Number of tickets" 
                onChange={(e) => setTicketsToTransfer(Number(e.target.value))} />
              <Input 
                className="m-2"
                type="text" 
                step={1} 
                min={1} 
                placeholder="Address of recipient" 
                onChange={(e) => setAddressToTransfer((e.target.value))} />
              <Button
                className='m-2' 
                disabled={Number(userTickets?.value) == 0 || Number(userTickets?.value) < ticketsToTransfer || ticketsToTransfer == 0 || isTransfering || isTransferingLoading}
                onClick={transferTickets}>
                  {isTransfering || isTransferingLoading? 'Transfering...' :  'Send ticket / s'}
              </Button>
            </CardContent>
          </Card>
          }
        </div>

        <Separator></Separator>

        <h1 className='text-3xl p-3'>
          Past Lotteries {/* add etherscan link of contract */}
        </h1>        
        <div className='grid grid-flow-row-dense grid-cols-3 grid-rows-3'>

          {Number(lotteryCount) === 0 &&
          <Card className='m-4 flex flex-col'>
            <h1 className='text-3xl pl-3 text-red-400'>No past lotteries</h1>
          </Card>
          }

          {pastLotteries.filter((lottery) => Number(lottery.winningAmount) != 0).map((lottery) => (
            <Card className='m-4 flex flex-col'>
            <CardHeader>
              <div className='flex'>
                <CardTitle className='mt-1 mr-1'>Lottery id: {lottery.id} </CardTitle>
                <Badge className='bg-red-400 mt-0'>Ended</Badge>
              </div>
              <CardTitle>
                Lottery address:  
                <a href={lotteryEtherscanLink(lottery.lotteryAddress)}>
                  { ' ' + lottery.lotteryAddress.slice(0, 6) + "..." + lottery.lotteryAddress.slice(38) } 
                </a>  
                <Button 
                  className="h-6 w-12 m-2" 
                  onClick={() =>copyLotteryAddress(lottery.lotteryAddress)}>
                    copy
                </Button> 
              </CardTitle>
              <Popover>
              <PopoverTrigger asChild>
                <Button className='w-min'variant="outline">More Info</Button>
              </PopoverTrigger>
              <PopoverContent>
                <PopoverHeader>
                  <PopoverDescription>
                    LotteryPrice: {Number(lottery.price)} Wei | {Number(lottery.price) / 10 ** 18} ETH
                  </PopoverDescription>
                  <PopoverDescription>
                    Lottery fee: {Number(lottery.fee) / 100} %
                  </PopoverDescription>
                  <PopoverDescription>
                    LotteryWinner: 
                    <a href={lotteryEtherscanLink(lottery.winner)}>
                      { ' ' + lottery.winner.slice(0, 6) + "..." + lottery.winner.slice(38) }
                    </a>
                    <Button 
                      className="h-6 w-10 m-2" 
                      onClick={() =>copyLotteryAddress(lottery.winner)}>
                        copy
                    </Button> 
                  </PopoverDescription>
                  <PopoverDescription>
                    Winning amount: {Number(lottery.winningAmount)} Wei |  {Number(lottery.winningAmount) / 10 ** 18} ETH
                  </PopoverDescription>       
                </PopoverHeader>
              </PopoverContent>
            </Popover>
            </CardHeader>

            <CardContent>
              <Image
                src={nftImages[Number(lottery.id)] ?? NftImage}
                alt="img"
                width={350}
                height={350}
                unoptimized  // needed for external IPFS URLs
              />
              <CardTitle> 
                NFT address: 
                <a href={lotteryEtherscanLink(lotteryNftContractConfig.address)}>
                  {' ' + lotteryNftContractConfig.address.slice(0, 6) + "..." + lotteryNftContractConfig.address.slice(38)}
                </a>                     
                <Button 
                  className="h-6 w-10 m-2" 
                  onClick={() =>copyLotteryAddress(lotteryNftContractConfig.address)}>
                    copy
                </Button> 
              </CardTitle>
            </CardContent>
            <CardFooter className='flex flex-col'>
            </CardFooter>
          </Card>  
          ))}
        </div>
      </main>

      <footer className={styles.footer}>
        <h5>
          Made by mksdznk. Full project code available on 
          <a href="https://github.com/mksdznk/blockchain-lottery">
            <Image src={GitHubImage} alt='GitHub' width={100} height={100}/>
          </a>
        </h5>
      </footer>
    </div>
  );
};

export default Lotteries;
