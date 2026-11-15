import { useCallback } from "react";
import type { AnchorHTMLAttributes, ReactNode } from "react";
import { AppProvider } from "@shopify/polaris";
import "@shopify/polaris/build/esm/styles.css";
import en from "@shopify/polaris/locales/en.json";

// The props Polaris passes to its link component.
type LinkProps = {
  url: string;
  children?: ReactNode;
  external?: boolean;
} & AnchorHTMLAttributes<HTMLAnchorElement>;

function AppBridgeLink({ url, children, external, ...rest }: LinkProps) {
  const handleClick = useCallback(() => window.open(url), [url]);

  const IS_EXTERNAL_LINK_REGEX = /^(?:[a-z][a-z\d+.-]*:|\/\/)/;

  if (external || IS_EXTERNAL_LINK_REGEX.test(url)) {
    return (
      <a {...rest} href={url} target="_blank" rel="noopener noreferrer">
        {children}
      </a>
    );
  }

  return (
    <a {...rest} onClick={handleClick}>
      {children}
    </a>
  );
}

/**
 * Sets up the AppProvider from Polaris.
 * @desc PolarisProvider passes a custom link component to Polaris.
 * The Link component handles navigation within an embedded app.
 * Prefer using this vs any other method such as an anchor.
 * Use it by importing Link from Polaris, e.g:
 *
 * ```
 * import {Link} from '@shopify/polaris'
 *
 * function MyComponent() {
 *  return (
 *    <div><Link url="/tab2">Tab 2</Link></div>
 *  )
 * }
 * ```
 *
 * PolarisProvider also gives Polaris its English text (the app is English only).
 *
 */
export function PolarisProvider({ children }: { children: ReactNode }) {
  return (
    <AppProvider i18n={en} linkComponent={AppBridgeLink}>
      {children}
    </AppProvider>
  );
}
