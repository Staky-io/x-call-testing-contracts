export const getNetworkSettings = (network: string): { callService: string, networkID: string } => {
    switch (network) {
        case 'sepolia':
            return {
                callService: '0x9B68bd3a04Ff138CaFfFe6D96Bc330c699F34901',
                networkID: '0xaa36a7.eth2',
            }
        case 'bsctestnet':
            return {
                callService: '0x6193c0b12116c4963594761d859571b9950a8686',
                networkID: '0x61.bsc',
            }
        case 'hardhat':
            return {
                callService: '0x9B68bd3a04Ff138CaFfFe6D96Bc330c699F34901',
                networkID: '0xaa36a7.eth2',
            }
        default:
            throw new Error('Invalid network')
    }
}