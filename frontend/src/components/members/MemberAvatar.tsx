/**
 * メンバー表示コンポーネント
 *
 * メンバー名を表示し、以下の機能を提供する:
 * - auth_locked=true の場合は名前の横に 🔒 アイコンを表示
 * - Discord スクリーン名が display_name と異なる場合、ホバー/タップで Tooltip 表示
 * - Core/Sub バッジを MemberRoleBadge で表示
 * - 選択状態のハイライト表示
 *
 * 要件: 1.2, 1.4, 2.3, 2.4
 */
import { Box, Chip, Tooltip } from "@mui/material";
import LockIcon from "@mui/icons-material/Lock";
import { useTranslation } from "react-i18next";
import type { Member } from "@/types/member";
import MemberRoleBadge from "@/components/members/MemberRoleBadge";

interface MemberAvatarProps {
  /** メンバー情報 */
  member: Member;
  /** 選択状態 */
  selected: boolean;
  /** クリック時のコールバック */
  onClick: () => void;
}

export default function MemberAvatar({
  member,
  selected,
  onClick,
}: MemberAvatarProps) {
  const { t } = useTranslation();

  /** Discord スクリーン名が表示名と異なるかどうか */
  const hasCustomName = member.display_name !== member.discord_screen_name;

  /** Tooltip に表示するテキスト */
  const tooltipText = hasCustomName
    ? `Discord: ${member.discord_screen_name}`
    : "";

  /** Chip のラベル（名前 + 🔒 アイコン） */
  const chipLabel = (
    <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
      <span>{member.display_name}</span>
      {member.auth_locked && (
        <LockIcon
          sx={{ fontSize: 14 }}
          aria-label={t("member.authLocked")}
        />
      )}
    </Box>
  );

  /** メンバー Chip + 役割バッジ */
  const content = (
    <Box
      sx={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 0.5,
      }}
    >
      <Chip
        label={chipLabel}
        onClick={onClick}
        color={selected ? "primary" : "default"}
        variant={selected ? "filled" : "outlined"}
        clickable
        aria-pressed={selected}
        aria-label={`${member.display_name}${member.auth_locked ? ` (${t("member.authLocked")})` : ""}`}
      />
      <MemberRoleBadge role={member.role} />
    </Box>
  );

  /* Discord スクリーン名が異なる場合のみ Tooltip でラップ */
  if (hasCustomName) {
    return (
      <Tooltip title={tooltipText} enterTouchDelay={0}>
        {content}
      </Tooltip>
    );
  }

  return content;
}
