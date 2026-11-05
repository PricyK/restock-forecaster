import { useState } from "react";
import { Banner, Modal, SkeletonBodyText, Tabs } from "@shopify/polaris";
import { useQuery } from "react-query";

import { fetchJson } from "../utils/fetchJson";
import { productName } from "../utils/productName";
import { SalesChart } from "./SalesChart";

// row is a forecast row, or null while the window is closed.
export function SalesHistoryModal({ row, onClose }) {
  const [tab, setTab] = useState(0);
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
    <Modal open={Boolean(row)} onClose={onClose} title={title} small>
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
            <SalesChart range={range} />
          </Tabs>
        )}
      </Modal.Section>
    </Modal>
  );
}
