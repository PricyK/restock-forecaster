import {
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
import { RISK_BADGES, RiskBadge, SalesHistoryModal } from "../components";
import { fetchJson } from "../utils/fetchJson";
import { productName } from "../utils/productName";

const SUMMARY_RISKS = ["out_of_stock", "critical", "warning"];

// Three equal boxes above the table. Clicking one shows only that risk's rows; clicking it again shows all.
function RiskSummary({ rows, active, onFilter }) {
  return (
    <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)" }}>
      {SUMMARY_RISKS.map((risk, i) => {
        const count = rows.filter((row) => row.risk === risk).length;
        return (
          <div
            key={risk}
            style={{
              borderLeft: i > 0 ? "1px solid var(--p-divider)" : undefined,
              padding: "0 var(--p-space-2)",
            }}
          >
            <UnstyledButton
              className="summary-button"
              pressed={risk === active}
              disabled={count === 0}
              accessibilityLabel={`Show only ${RISK_BADGES[risk].label.toLowerCase()} products (${count})`}
              onClick={() => onFilter(risk === active ? null : risk)}
            >
              <RiskBadge risk={risk} />
              <Text as="p" variant="heading2xl">
                {count}
              </Text>
            </UnstyledButton>
          </div>
        );
      })}
    </div>
  );
}

function ForecastTable({ rows, onSelect }) {
  const [filter, setFilter] = useState(null);

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

  // A filter whose count dropped to 0 after a refresh is dropped, so the table never goes empty.
  const active = rows.some((row) => row.risk === filter) ? filter : null;
  const shown = active ? rows.filter((row) => row.risk === active) : rows;

  return (
    <Card>
      <Card.Section>
        <RiskSummary rows={rows} active={active} onFilter={setFilter} />
      </Card.Section>
      <DataTable
        columnContentTypes={["text", "text", "text", "numeric", "text"]}
        headings={["Product", "Category", "SKU", "Stock", "Risk"]}
        rows={shown.map((row) => [
          productName(row),
          row.category ?? "—",
          row.sku ?? "",
          row.inventory,
          // The label replaces the badge text for screen readers, so it keeps the risk word.
          <UnstyledButton
            key={row.id}
            className="badge-button"
            accessibilityLabel={`${RISK_BADGES[row.risk].label}: sales history for ${productName(row)}`}
            onClick={() => onSelect(row)}
          >
            <RiskBadge risk={row.risk} />
          </UnstyledButton>,
        ])}
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
