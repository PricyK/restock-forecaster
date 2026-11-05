import {
  Badge,
  Banner,
  Card,
  DataTable,
  EmptyState,
  Layout,
  Page,
  SkeletonBodyText,
  Text,
  UnstyledButton,
} from "@shopify/polaris";
import { useState } from "react";
import { useQuery } from "react-query";

import { notFoundImage } from "../assets";
import { SalesHistoryModal } from "../components";
import { fetchJson } from "../utils/fetchJson";
import { productName } from "../utils/productName";

const RISK_BADGES = {
  out_of_stock: { status: "critical", label: "Out of stock", strong: true },
  critical: { status: "critical", label: "Critical" },
  warning: { status: "warning", label: "Warning" },
  ok: { status: "success", label: "OK" },
  no_recent_sales: { label: "No recent sales" },
};

const SUMMARY_RISKS = ["out_of_stock", "critical", "warning"];

// The strong class gives "Out of stock" a deeper red than "Critical" (see index.html).
function RiskBadge({ risk }) {
  const badge = RISK_BADGES[risk];
  return (
    <span className={badge.strong ? "badge-strong" : undefined}>
      <Badge status={badge.status}>{badge.label}</Badge>
    </span>
  );
}

// Three equal boxes above the table: how many rows are out of stock, critical, and warning.
function RiskSummary({ rows }) {
  return (
    <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)" }}>
      {SUMMARY_RISKS.map((risk, i) => (
        <div
          key={risk}
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: "var(--p-space-3)",
            borderLeft: i > 0 ? "1px solid var(--p-divider)" : undefined,
          }}
        >
          <RiskBadge risk={risk} />
          <Text as="p" variant="heading2xl">
            {rows.filter((row) => row.risk === risk).length}
          </Text>
        </div>
      ))}
    </div>
  );
}

function ForecastTable({ rows, onSelect }) {
  if (rows.length === 0) {
    return (
      <Card sectioned>
        <EmptyState heading="No products yet" image={notFoundImage}>
          <p>
            Add products that track inventory to see when they will run out.
          </p>
        </EmptyState>
      </Card>
    );
  }

  return (
    <Card>
      <Card.Section>
        <RiskSummary rows={rows} />
      </Card.Section>
      <DataTable
        columnContentTypes={[
          "text",
          "text",
          "text",
          "numeric",
          "numeric",
          "text",
        ]}
        headings={["Product", "Category", "SKU", "Stock", "Days left", "Risk"]}
        rows={rows.map((row) => {
          return [
            productName(row),
            row.category ?? "—",
            row.sku ?? "",
            row.inventory,
            row.days_left ?? "—",
            // The label replaces the badge text for screen readers, so it keeps the risk word.
            <UnstyledButton
              key={row.id}
              className="badge-button"
              accessibilityLabel={`${RISK_BADGES[row.risk].label}: sales history for ${productName(row)}`}
              onClick={() => onSelect(row)}
            >
              <RiskBadge risk={row.risk} />
            </UnstyledButton>,
          ];
        })}
      />
    </Card>
  );
}

export default function HomePage() {
  const [selected, setSelected] = useState(null);
  const { data, error, isLoading, isFetching, refetch } = useQuery({
    queryKey: ["forecast"],
    queryFn: () => fetchJson("/api/forecast"),
    refetchOnWindowFocus: false,
    retry: false,
  });

  return (
    <Page
      title="Restock Forecaster"
      primaryAction={{
        content: "Refresh",
        onAction: () => refetch(),
        loading: isFetching,
        disabled: isLoading,
      }}
    >
      <Layout>
        {error && (
          <Layout.Section>
            <Banner
              status="critical"
              title="Couldn't load the forecast"
              action={{
                content: "Retry",
                onAction: () => refetch(),
                loading: isFetching,
              }}
            >
              <p>{error.message}</p>
            </Banner>
          </Layout.Section>
        )}
        <Layout.Section>
          {isLoading && (
            <Card sectioned>
              <SkeletonBodyText lines={6} />
            </Card>
          )}
          {data && <ForecastTable rows={data.rows} onSelect={setSelected} />}
        </Layout.Section>
      </Layout>
      <SalesHistoryModal row={selected} onClose={() => setSelected(null)} />
    </Page>
  );
}
