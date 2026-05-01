/**
 * メンバー選択バーコンポーネント
 *
 * メンバー名を横並びで表示し、クリック/タップで選択する。
 * - 選択中のメンバーはハイライト表示（primary カラー）
 * - localStorage に selectedUserId を保存し、次回アクセス時に自動選択
 * - 🔒 付きユーザー（auth_locked=true）選択時は GoogleLoginButton を表示
 *
 * 要件: 1.2, 1.3, 1.5, 2.3, 2.4
 */
import { Box, Typography } from "@mui/material";
import { useTranslation } from "react-i18next";
import type { Member } from "@/types/member";
import MemberAvatar from "@/components/members/MemberAvatar";
import GoogleLoginButton from "@/components/auth/GoogleLoginButton";

interface MemberSelectorProps {
  /** メンバー一覧 */
  members: Member[];
  /** 現在選択中のユーザー ID */
  selectedUserId: number | null;
  /** ユーザー選択時のコールバック */
  onSelectUser: (userId: number) => void;
}

/** localStorage のキー名 */
const STORAGE_KEY = "selectedUserId";

/**
 * localStorage に選択ユーザー ID を保存する
 */
function saveSelectedUserId(userId: number): void {
  try {
    localStorage.setItem(STORAGE_KEY, String(userId));
  } catch {
    /* シークレットモード等で localStorage が使えない場合は無視 */
  }
}

/**
 * localStorage から選択ユーザー ID を読み込む
 */
export function loadSelectedUserId(): number | null {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored === null) return null;
    const parsed = Number(stored);
    return Number.isFinite(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

export default function MemberSelector({
  members,
  selectedUserId,
  onSelectUser,
}: MemberSelectorProps) {
  const { t } = useTranslation();

  /** 選択中のメンバー情報 */
  const selectedMember = members.find((m) => m.id === selectedUserId) ?? null;

  /** メンバー選択ハンドラー */
  const handleSelect = (userId: number) => {
    saveSelectedUserId(userId);
    onSelectUser(userId);
  };

  return (
    <Box sx={{ mb: 2 }}>
      {/* タイトル */}
      <Typography variant="subtitle2" sx={{ mb: 1 }}>
        {t("member.selector.title")}
      </Typography>

      {/* メンバー一覧（横並び） */}
      <Box
        sx={{
          display: "flex",
          flexWrap: "wrap",
          gap: 1.5,
          alignItems: "flex-start",
        }}
        role="listbox"
        aria-label={t("member.selector.title")}
      >
        {members.map((member) => (
          <MemberAvatar
            key={member.id}
            member={member}
            selected={member.id === selectedUserId}
            onClick={() => handleSelect(member.id)}
          />
        ))}
      </Box>

      {/* 🔒 付きユーザー選択時は Google ログインボタンを表示 */}
      {selectedMember?.auth_locked && (
        <Box sx={{ mt: 2 }}>
          <GoogleLoginButton />
        </Box>
      )}
    </Box>
  );
}
