import { useState } from "react";
import { Banner, Modal, SkeletonBodyText, Tabs, Text } from "@shopify/polaris";
import { useQuery } from "react-query";

import { fetchJson } from "../utils/fetchJson";
import { productName } from "../utils/productName";
import { SalesChart } from "./SalesChart";

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
  const title = row ? productName(row) : "";
  const range = data?.ranges[tab];

  return (
    <Modal
      open={Boolean(row)}
      onClose={onClose}
      title={title}
      small={!expanded}
      large={expanded}
      secondaryActions={[
        {
          content: expanded ? "Shrink" : "Expand",
          onAction: () => setExpanded(!expanded),
        },
      ]}
    >
      {row && (
        <Modal.Section>
          <Text as="p" variant="headingMd">
            {stockLeft(row)}
          </Text>
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
    </Modal>
  );
}
