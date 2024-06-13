/* eslint-disable */
export type Maybe<T> = T | null;
export type InputMaybe<T> = Maybe<T>;
export type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };
export type MakeOptional<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]?: Maybe<T[SubKey]> };
export type MakeMaybe<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]: Maybe<T[SubKey]> };
export type MakeEmpty<T extends { [key: string]: unknown }, K extends keyof T> = { [_ in K]?: never };
export type Incremental<T> = T | { [P in keyof T]?: P extends ' $fragmentName' | '__typename' ? T[P] : never };
/** All built-in and custom scalars, mapped to their actual values */
export type Scalars = {
  ID: { input: string; output: string; }
  String: { input: string; output: string; }
  Boolean: { input: boolean; output: boolean; }
  Int: { input: number; output: number; }
  Float: { input: number; output: number; }
  /** Represents non-fractional signed whole numeric values. Since the value may exceed the size of a 32-bit integer, it's encoded as a string. */
  BigInt: { input: any; output: any; }
};

export type BalanceSheet = {
  __typename?: 'BalanceSheet';
  amount?: Maybe<BalanceSheetAmount>;
  ratio?: Maybe<BalanceSheetRatio>;
};

export type BalanceSheetAmount = {
  __typename?: 'BalanceSheetAmount';
  currentAsset?: Maybe<Scalars['BigInt']['output']>;
  currentLiability?: Maybe<Scalars['BigInt']['output']>;
  intangibleAsset?: Maybe<Scalars['BigInt']['output']>;
  investmentAndOtherAsset?: Maybe<Scalars['BigInt']['output']>;
  netAsset?: Maybe<Scalars['BigInt']['output']>;
  noncurrentLiability?: Maybe<Scalars['BigInt']['output']>;
  propertyPlantAndEquipment?: Maybe<Scalars['BigInt']['output']>;
};

export type BalanceSheetRatio = {
  __typename?: 'BalanceSheetRatio';
  currentAsset?: Maybe<Scalars['Float']['output']>;
  currentLiability?: Maybe<Scalars['Float']['output']>;
  intangibleAsset?: Maybe<Scalars['Float']['output']>;
  investmentAndOtherAsset?: Maybe<Scalars['Float']['output']>;
  netAsset?: Maybe<Scalars['Float']['output']>;
  noncurrentLiability?: Maybe<Scalars['Float']['output']>;
  propertyPlantAndEquipment?: Maybe<Scalars['Float']['output']>;
};

export type CashFlow = {
  __typename?: 'CashFlow';
  endingCash?: Maybe<Scalars['BigInt']['output']>;
  financingActivitiesCashFlow?: Maybe<Scalars['BigInt']['output']>;
  investingActivitiesCashFlow?: Maybe<Scalars['BigInt']['output']>;
  operatingActivitiesCashFlow?: Maybe<Scalars['BigInt']['output']>;
  startingCash?: Maybe<Scalars['BigInt']['output']>;
};

export type CompanyFinancialStatement = {
  __typename?: 'CompanyFinancialStatement';
  balanceSheet?: Maybe<BalanceSheet>;
  cashFlow?: Maybe<CashFlow>;
  companyJapaneseName?: Maybe<Scalars['String']['output']>;
  consolidatedInductoryCode?: Maybe<Scalars['String']['output']>;
  filingDate?: Maybe<Scalars['String']['output']>;
  fiscalYearEndDate?: Maybe<Scalars['String']['output']>;
  fiscalYearStartDate?: Maybe<Scalars['String']['output']>;
  hasConsolidatedFinancialStatement?: Maybe<Scalars['Boolean']['output']>;
  id: Scalars['ID']['output'];
  nonConsolidatedInductoryCode?: Maybe<Scalars['String']['output']>;
  profitLoss?: Maybe<ProfitLoss>;
  stockCode?: Maybe<Scalars['String']['output']>;
};

export type Mutation = {
  __typename?: 'Mutation';
  sandboxTest?: Maybe<SandboxTestPayload>;
};


export type MutationSandboxTestArgs = {
  input: SandboxTestInput;
};

export enum NumberSign {
  Negative = 'NEGATIVE',
  Positive = 'POSITIVE'
}

export type ProfitLoss = {
  __typename?: 'ProfitLoss';
  amount?: Maybe<ProfitLossAmount>;
  ratio?: Maybe<ProfitLossRatio>;
};

export type ProfitLossAmount = {
  __typename?: 'ProfitLossAmount';
  netSales?: Maybe<Scalars['BigInt']['output']>;
  operatingIncome?: Maybe<Scalars['BigInt']['output']>;
  originalCost?: Maybe<Scalars['BigInt']['output']>;
  sellingGeneralExpense?: Maybe<Scalars['BigInt']['output']>;
};

export type ProfitLossRatio = {
  __typename?: 'ProfitLossRatio';
  netSales?: Maybe<Scalars['Float']['output']>;
  operatingIncome?: Maybe<Scalars['Float']['output']>;
  originalCost?: Maybe<Scalars['Float']['output']>;
  sellingGeneralExpense?: Maybe<Scalars['Float']['output']>;
};

export type Query = {
  __typename?: 'Query';
  /** Find Company Financial Statement by limit */
  companyFinancialStatements?: Maybe<Array<CompanyFinancialStatement>>;
};


export type QueryCompanyFinancialStatementsArgs = {
  financingActivitiesCashFlowSign?: InputMaybe<NumberSign>;
  investingActivitiesCashFlowSign?: InputMaybe<NumberSign>;
  limit: Scalars['Int']['input'];
  offset: Scalars['Int']['input'];
  operatingActivitiesCashFlowSign?: InputMaybe<NumberSign>;
  stockCodes?: InputMaybe<Array<Scalars['String']['input']>>;
};

export type SandboxBookmark = {
  documentId: Scalars['String']['input'];
  userId: Scalars['String']['input'];
};

/** this is Sandbox type to practice GraphQL */
export type SandboxTest = {
  __typename?: 'SandboxTest';
  id: Scalars['ID']['output'];
  rating?: Maybe<Scalars['Int']['output']>;
  title?: Maybe<Scalars['String']['output']>;
};

/** Autogenerated input type of SandboxTest */
export type SandboxTestInput = {
  attributes: SandboxBookmark;
  /** A unique identifier for the client performing the mutation. */
  clientMutationId?: InputMaybe<Scalars['String']['input']>;
};

/** Autogenerated return type of SandboxTest. */
export type SandboxTestPayload = {
  __typename?: 'SandboxTestPayload';
  /** A unique identifier for the client performing the mutation. */
  clientMutationId?: Maybe<Scalars['String']['output']>;
  sandboxTestaa: SandboxTest;
};
