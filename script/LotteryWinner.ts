// this is the offchain calculation which runs on chain link to calculate the lottery winner

try {
  const lotteryAddress = args[0];
  let chain;
  if (args[1] == 1) {
      chain = 'eth';
  }
  else if (args[1] == 11155111) {
      chain = 'sepolia';
  }
  const randomNumber = args[2];

  let response = await Functions.makeHttpRequest({
    method: 'GET',
    url: `https://deep-index.moralis.io/api/v2.2/erc20/${lotteryAddress}/owners`,
    params: {
      chain: chain,
      limit: '100',
      order: 'DESC'
    },
    headers: {
      accept: 'application/json',
      'X-API-Key': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJub25jZSI6IjM3NWJhN2U0LWI5OGItNDMyMS04ZDZlLWU2ZjFlZjBlOGJkOSIsIm9yZ0lkIjoiNDk0MTg2IiwidXNlcklkIjoiNTA4NTM1IiwidHlwZUlkIjoiYjEzNGI4YmMtMjA3MS00ODk4LWE3OTItZDU0MjlmNGE2ZDdjIiwidHlwZSI6IlBST0pFQ1QiLCJpYXQiOjE3NjkxNzkzNzEsImV4cCI6NDkyNDkzOTM3MX0.IFUfq-1G7tyUOFFfsM4lsWEQJzY9qiZHtP_1KSuv5Hk'
    }
  });

    let lotteryEntries = response.data.result;
    let lotteryAddresses = [];
    let entriesForAddress = 0;
    let cursor = response.data.cursor;

    for (let i = 0; i < lotteryEntries.length; i++) {
        entriesForAddress = lotteryEntries[i].balance;
        for (let j = 0; j < entriesForAddress; j++) {
          lotteryAddresses.push(lotteryEntries[i].owner_address);
        }
    }

    //cusor points to next page if too many data entries for one API call
    while (cursor != null) {
      response = await Functions.makeHttpRequest({
        method: 'GET',
        url: `https://deep-index.moralis.io/api/v2.2/erc20/${lotteryAddress}/owners`,
        params: {
          chain: chain,
          limit: '100',
          order: 'DESC',
          cursor: cursor,
        },
        headers: {
          accept: 'application/json',
          'X-API-Key': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJub25jZSI6IjM3NWJhN2U0LWI5OGItNDMyMS04ZDZlLWU2ZjFlZjBlOGJkOSIsIm9yZ0lkIjoiNDk0MTg2IiwidXNlcklkIjoiNTA4NTM1IiwidHlwZUlkIjoiYjEzNGI4YmMtMjA3MS00ODk4LWE3OTItZDU0MjlmNGE2ZDdjIiwidHlwZSI6IlBST0pFQ1QiLCJpYXQiOjE3NjkxNzkzNzEsImV4cCI6NDkyNDkzOTM3MX0.IFUfq-1G7tyUOFFfsM4lsWEQJzY9qiZHtP_1KSuv5Hk'
        }
      });

      lotteryEntries = response.data.result;
      entriesForAddress = 0;
      cursor = response.data.cursor;

      for (let i = 0; i < lotteryEntries.length; i++) {
        entriesForAddress = lotteryEntries[i].balance;
        for (let j = 0; j < entriesForAddress; j++) {
          lotteryAddresses.push(lotteryEntries[i].owner_address);
        }
      }
    }

  if (response.error) {
    throw new Error(`API error: ${response.error}`);
  }

    const winnerIndex = randomNumber % lotteryAddresses.length;

    return Functions.encodeString(lotteryAddresses[winnerIndex]);

} catch (error) {
  console.error('Error:', error);
  return Functions.encodeString(JSON.stringify({
    success: false,
    error: error.message
  }));
}
