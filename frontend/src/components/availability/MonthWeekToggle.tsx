/**
 * 月/週表示切り替えコンポーネント
 *
 * MUI ToggleButtonGroup を使用して月単位（デフォルト）と週単位の
 * 表示モードを切り替える。
 *
 * 要件: 4.2
 */
import { ToggleButton, ToggleButtonGroup } from "@mui/material";
import { useTranslation } from "react-i18next";

/** 表示モード */
export type ViewMode = "month" | "week";

interface MonthWeekToggleProps {
  /** 現在の表示モード */
  viewMode: ViewMode;
  /** 表示モード変更時のコールバック */
  onViewModeChange: (mode: ViewMode) => void;
}

export default function MonthWeekToggle({
  viewMode,
  onViewModeChange,
}: MonthWeekToggleProps) {
  const { t } = useTranslation();

  const handleChange = (
    _event: React.MouseEvent<HTMLElement>,
    newMode: ViewMode | null,
  ) => {
    /* null の場合は現在の選択を維持（トグル解除を防止） */
    if (newMode !== null) {
      onViewModeChange(newMode);
    }
  };

  return (
    <ToggleButtonGroup
      value={viewMode}
      exclusive
      onChange={handleChange}
      size="small"
      aria-label={t("common.month") + " / " + t("common.week")}
    >
      <ToggleButton value="month" data-testid="toggle-month">
        {t("common.month")}
      </ToggleButton>
      <ToggleButton value="week" data-testid="toggle-week">
        {t("common.week")}
      </ToggleButton>
    </ToggleButtonGroup>
  );
}
