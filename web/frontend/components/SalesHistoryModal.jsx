import { useState } from "react";
import {
  Banner,
  Button,
  Modal,
  SkeletonBodyText,
  Tabs,
  Text,
} from "@shopify/polaris";
import { useQuery } from "react-query";

import { fetchJson } from "../utils/fetchJson";
import { productName } from "../utils/productName";
import { RiskBadge } from "./RiskBadge";
import { SalesChart, rangeTotal } from "./SalesChart";

// Two corner triangles, like the macOS full-screen button: pointing out to expand, in to shrink.
const ExpandIcon = (props) => (
  <svg viewBox="0 0 20 20" {...props}>
    <path d="M4 4h8l-8 8zM16 16H8l8-8z" />
  </svg>
);
const ShrinkIcon = (props) => (
  <svg viewBox="0 0 20 20" {...props}>
    <path d="M9 9H2l7-7zM11 11h7l-7 7z" />
  </svg>
);

// The forecast's days left, in words. The table has no Days left column, so the window says it.
export function stockLeft(row) {
  if (row.risk === "out_of_stock") return "Out of stock now.";
  if (row.days_left === null) {
    return "No sales in the last 30 days, so no run-out estimate.";
  }
  if (row.days_left === 0) return "Less than a day of stock left.";
  return `About ${row.days_left} ${row.days_left === 1 ? "day" : "days"} of stock left.`;
}

// row is a forecast row, or null while the window is closed.
export function SalesHistoryModal({ row, onClose }) {
  const [tab, setTab] = useState(0);
  const [expanded, setExpanded] = useState(false);
  const { data, error, isLoading, isFetching, refetch } = useQuery({
    queryKey: ["sales_history", row?.id],
    queryFn: () =>
      fetchJson(`/api/sales_history?variant_id=${encodeURIComponent(row.id)}`),
    enabled: Boolean(row),
    retry: false,
    refetchOnWindowFocus: false,
  });
  // The size button sits in the title so it lands just left of the X (see .window-title in index.html).
  const title = row ? (
    <span className="window-title">
      {productName(row)}
      <Button
        plain
        icon={expanded ? ShrinkIcon : ExpandIcon}
        accessibilityLabel={expanded ? "Shrink window" : "Expand window"}
        onClick={() => setExpanded(!expanded)}
      />
    </span>
  ) : (
    ""
  );
  const range = data?.ranges[tab];

  return (
    <Modal
      open={Boolean(row)}
      onClose={onClose}
      title={title}
      small={!expanded}
      large={expanded}
    >
      {row && (
        <Modal.Section>
          <RiskBadge risk={row.risk}>{stockLeft(row)}</RiskBadge>
        </Modal.Section>
      )}
      <Modal.Section>
        {isLoading && <SkeletonBodyText lines={4} />}
        {error && (
          <Banner
            status="critical"
            title="Couldn't load sales history"
            action={{
              content: "Retry",
              onAction: () => refetch(),
              loading: isFetching,
            }}
          >
            <p>{error.message}</p>
          </Banner>
        )}
        {data && (
          <Tabs
            tabs={data.ranges.map((r, i) => ({
              id: `range-${i}`,
              content: r.label,
            }))}
            selected={tab}
            onSelect={setTab}
          >
            <SalesChart range={range} wide={expanded} />
          </Tabs>
        )}
      </Modal.Section>
      {data && (
        // Its own section, so Polaris adds the same spacing and divider line as the days-left line at the top.
        <Modal.Section>
          <Text as="p" variant="headingMd" alignment="center">
            {rangeTotal(range)} sold in the last {range.label}
          </Text>
        </Modal.Section>
      )}
    </Modal>
  );
}
