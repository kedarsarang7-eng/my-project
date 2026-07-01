/**
 * Fixture: GraphQL operations embedded in a `gql` tagged template literal.
 *
 * Exercises the code scanner's GraphQL tagged-template extraction
 * (Requirement 1.4). The template has no `${}` substitutions so it parses.
 */
import { gql } from 'graphql-tag';

export const GET_PRODUCTS = gql`
  query GetProducts {
    products {
      id
      name
    }
  }

  mutation CreateProduct {
    createProduct(name: "x") {
      id
    }
  }
`;
