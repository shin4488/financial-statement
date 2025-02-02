import { Query } from '@/__generated__/graphql';
import {
  ApolloClient,
  InMemoryCache,
  NormalizedCacheObject,
  gql,
} from '@apollo/client';

export default class ApolloClientService {
  static client: ApolloClient<NormalizedCacheObject> | null = null;
  constructor() {
    if (ApolloClientService.client === null) {
      ApolloClientService.client = this.create();
    }
  }

  create(): ApolloClient<NormalizedCacheObject> {
    return new ApolloClient({
      uri: '/api/graphql',
      cache: new InMemoryCache(),
    });
  }

  async query(literals: string | readonly string[]) {
    if (ApolloClientService.client === null) {
      ApolloClientService.client = this.create();
    }

    const result = await ApolloClientService.client.query<Query>({
      query: gql(literals),
    });
    if (result.error !== undefined) {
      throw Error(result.error.message);
    }

    return result.data;
  }
}
