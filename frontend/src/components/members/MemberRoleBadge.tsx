/**
 * メンバー役割バッジコンポーネント
 *
 * Core / Sub / Owner の役割を MUI Chip で表示する。
 * - Owner: primary カラー
 * - Core: secondary カラー
 * - Sub: default
 *
 * 要件: 2.4, 2.5
 */
import { Chip } from "@mui/material";
import { useTranslation } from "react-i18next";

interface MemberRoleBadgeProps {
  /** メンバーの役割 */
  role: "owner" | "core" | "sub";
}

/** 役割ごとの Chip カラー設定 */
const roleColorMap: Record<
  MemberRoleBadgeProps["role"],
  "primary" | "secondary" | "default"
> = {
  owner: "primary",
  core: "secondary",
  sub: "default",
};

export default function MemberRoleBadge({ role }: MemberRoleBadgeProps) {
  const { t } = useTranslation();

  /** 役割ごとの i18n キー */
  const roleLabelMap: Record<MemberRoleBadgeProps["role"], string> = {
    owner: t("member.role.owner"),
    core: t("member.role.core"),
    sub: t("member.role.sub"),
  };

  return (
    <Chip
      label={roleLabelMap[role]}
      color={roleColorMap[role]}
      size="small"
      sx={{ fontSize: "0.7rem", height: 20 }}
    />
  );
}
