/**
 * カレンダー形式の参加可否一覧表示コンポーネント
 *
 * 全メンバーの参加可否を日付ごとにカレンダー形式で表示する。
 * - 月単位（デフォルト）/ 週単位の切り替え
 * - 月送りナビゲーション
 * - Core_Member と Sub_Member を区別して表示
 * - レスポンシブ対応（PC: フルテーブル、スマートフォン: スクロール対応）
 * - AvailabilityCell による参加可否セルの表示・入力
 * - AvailabilitySummary による日別集計表示と警告色
 * - 過去日付のロック表示（一般メンバーは閲覧のみ、Owner は編集可能）
 *
 * 要件: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.9, 3.1, 3.2, 4.11, 4.12, 3.7, 3.8
 */
import { useState, useMemo, useCallback } from "react";
import {
  Box,
  IconButton,
  Typography,
  Table,
  TableHead,
  TableBody,
  TableRow,
  TableCell,
  Paper,
  Divider,
} from "@mui/material";
import ChevronLeftIcon from "@mui/icons-material/ChevronLeft";
import ChevronRightIcon from "@mui/icons-material/ChevronRight";
import { useTranslation } from "react-i18next";
import type { Group } from "@/types/group";
import type { Member } from "@/types/member";
import type {
  AvailabilitiesMap,
  EventDaysMap,
  SummaryMap,
} from "@/types/availability";
import type {
  SupportedLocale,
  AvailabilityStatus,
} from "@/utils/availabilitySymbols";
import MonthWeekToggle, { type ViewMode } from "./MonthWeekToggle";
import AvailabilityCell from "./AvailabilityCell";
import AvailabilitySummary, {
  getRowHighlight,
  ROW_HIGHLIGHT_COLORS,
} from "./AvailabilitySummary";
import CommentTooltip from "./CommentTooltip";
import EventDayMarker from "./EventDayMarker";

interface AvailabilityBoardProps {
  /** グループ情報 */
  group: Group;
  /** メンバー一覧 */
  members: Member[];
  /** 参加可否データ */
  availabilities: AvailabilitiesMap;
  /** 活動日データ */
  eventDays: EventDaysMap;
  /** 集計データ */
  summary: SummaryMap;
  /** 選択中のユーザー ID */
  selectedUserId: number | null;
  /** ロケール */
  locale: SupportedLocale;
  /** セルクリック時のコールバック（後方互換用） */
  onCellClick?: (date: string, memberId: number) => void;
  /** ステータス変更時のコールバック */
  onStatusChange?: (
    date: string,
    memberId: number,
    newStatus: AvailabilityStatus,
  ) => void;
  /** コメント保存時のコールバック */
  onCommentSave?: (
    date: string,
    memberId: number,
    comment: string,
  ) => void;
  /** 現在の月が変更された時のコールバック */
  onMonthChange?: (month: string) => void;
}

/**
 * 指定月の全日付を生成する
 */
function generateMonthDates(year: number, month: number): Date[] {
  const dates: Date[] = [];
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  for (let day = 1; day <= daysInMonth; day++) {
    dates.push(new Date(year, month, day));
  }
  return dates;
}

/**
 * 指定日を含む週の日付を生成する（月曜始まり）
 */
function generateWeekDates(baseDate: Date): Date[] {
  const dates: Date[] = [];
  const day = baseDate.getDay();
  /* 月曜始まり: 日曜(0)→6, 月曜(1)→0, ... 土曜(6)→5 */
  const mondayOffset = day === 0 ? 6 : day - 1;
  const monday = new Date(baseDate);
  monday.setDate(baseDate.getDate() - mondayOffset);
  for (let i = 0; i < 7; i++) {
    const d = new Date(monday);
    d.setDate(monday.getDate() + i);
    dates.push(d);
  }
  return dates;
}

/**
 * Date を YYYY-MM-DD 形式の文字列に変換する
 */
function formatDateKey(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/**
 * Date を YYYY-MM 形式の文字列に変換する
 */
export function formatMonthKey(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  return `${y}-${m}`;
}

/**
 * メンバーを Core / Sub にグループ分けする
 * owner と core は「コアグループ」、sub は「サブグループ」
 */
function groupMembers(members: Member[]): {
  coreMembers: Member[];
  subMembers: Member[];
} {
  const coreMembers = members.filter(
    (m) => m.role === "owner" || m.role === "core",
  );
  const subMembers = members.filter((m) => m.role === "sub");
  return { coreMembers, subMembers };
}

/**
 * 指定日が過去の日付かどうかを判定する
 * 今日の日付の開始時点（0:00:00）と比較する
 */
export function isPastDate(dateKey: string): boolean {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const target = new Date(dateKey + "T00:00:00");
  return target < today;
}

export default function AvailabilityBoard({
  group,
  members,
  availabilities,
  eventDays,
  summary,
  selectedUserId,
  locale,
  onCellClick,
  onStatusChange,
  onCommentSave,
  onMonthChange,
}: AvailabilityBoardProps) {
  const { t } = useTranslation();

  /* 表示モード（月/週） */
  const [viewMode, setViewMode] = useState<ViewMode>("month");

  /* 現在表示中の基準日 */
  const [currentDate, setCurrentDate] = useState<Date>(() => new Date());

  /* コメントポップオーバーの開閉状態 */
  const [commentPopover, setCommentPopover] = useState<{
    date: string;
    memberId: number;
  } | null>(null);

  /* メンバーのグループ分け */
  const { coreMembers, subMembers } = useMemo(
    () => groupMembers(members),
    [members],
  );

  /* 選択中ユーザーが Owner かどうかを判定 */
  const isOwner = useMemo(() => {
    if (selectedUserId === null) return false;
    const selectedMember = members.find((m) => m.id === selectedUserId);
    return selectedMember?.role === "owner";
  }, [members, selectedUserId]);

  /* 表示する日付リスト */
  const dates = useMemo(() => {
    if (viewMode === "month") {
      return generateMonthDates(
        currentDate.getFullYear(),
        currentDate.getMonth(),
      );
    }
    return generateWeekDates(currentDate);
  }, [viewMode, currentDate]);

  /* 月送りナビゲーション */
  const handlePrevious = useCallback(() => {
    setCurrentDate((prev) => {
      const next = new Date(prev);
      if (viewMode === "month") {
        next.setMonth(next.getMonth() - 1);
      } else {
        next.setDate(next.getDate() - 7);
      }
      /* 月変更を通知 */
      onMonthChange?.(formatMonthKey(next));
      return next;
    });
  }, [viewMode, onMonthChange]);

  const handleNext = useCallback(() => {
    setCurrentDate((prev) => {
      const next = new Date(prev);
      if (viewMode === "month") {
        next.setMonth(next.getMonth() + 1);
      } else {
        next.setDate(next.getDate() + 7);
      }
      /* 月変更を通知 */
      onMonthChange?.(formatMonthKey(next));
      return next;
    });
  }, [viewMode, onMonthChange]);

  /* ヘッダーに表示する年月テキスト */
  const headerText = useMemo(() => {
    const year = currentDate.getFullYear();
    const month = currentDate.getMonth() + 1;
    if (locale === "en") {
      const monthNames = [
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
      ];
      return `${monthNames[currentDate.getMonth()]} ${year}`;
    }
    return `${year}年${month}月`;
  }, [currentDate, locale]);

  /**
   * セルクリックハンドラー
   * 選択中ユーザーのセルのみ status をサイクルして onStatusChange を呼ぶ
   * 新しい status が × (-1) または △ (0) の場合はコメントポップオーバーを開く
   * 過去日付は Owner 以外は編集不可
   */
  const handleCellClick = useCallback(
    (dateKey: string, memberId: number) => {
      /* 後方互換: onCellClick が渡されている場合は呼ぶ */
      onCellClick?.(dateKey, memberId);

      /* 選択中ユーザーのセルのみ編集可能 */
      if (onStatusChange && memberId === selectedUserId) {
        /* 過去日付は Owner 以外は編集不可 */
        if (isPastDate(dateKey) && !isOwner) {
          return;
        }

        const entry = availabilities[dateKey]?.[String(memberId)];
        const currentStatus: AvailabilityStatus = entry?.status ?? null;
        /* status をサイクル: null → 1 → 0 → -1 → null */
        let newStatus: AvailabilityStatus;
        switch (currentStatus) {
          case null:
            newStatus = 1;
            break;
          case 1:
            newStatus = 0;
            break;
          case 0:
            newStatus = -1;
            break;
          case -1:
            newStatus = null;
            break;
          default:
            newStatus = null;
        }
        onStatusChange(dateKey, memberId, newStatus);

        /* × (-1) または △ (0) の場合はコメントポップオーバーを開く */
        if (newStatus === -1 || newStatus === 0) {
          setCommentPopover({ date: dateKey, memberId });
        } else {
          setCommentPopover(null);
        }
      }
    },
    [onCellClick, onStatusChange, selectedUserId, availabilities, isOwner],
  );

  /**
   * コメント保存ハンドラー
   */
  const handleCommentSave = useCallback(
    (date: string, memberId: number, comment: string) => {
      onCommentSave?.(date, memberId, comment);
      setCommentPopover(null);
    },
    [onCommentSave],
  );

  /**
   * コメントポップオーバーを閉じるハンドラー
   */
  const handleCommentClose = useCallback(() => {
    setCommentPopover(null);
  }, []);

  /**
   * メンバーセルをレンダリングする共通関数
   * コメントがある場合やポップオーバー表示中は CommentTooltip でラップする
   * 過去日付は Owner 以外は閲覧のみ（ロック表示）
   */
  const renderMemberCell = (
    member: Member,
    dateKey: string,
  ) => {
    const entry = availabilities[dateKey]?.[String(member.id)];
    const status: AvailabilityStatus = entry?.status ?? null;
    const comment = entry?.comment ?? null;
    const autoSynced = entry?.auto_synced ?? false;
    const past = isPastDate(dateKey);
    /* 過去日付かつ Owner でない場合はロック */
    const isPastLocked = past && !isOwner;
    const isEditable =
      member.id === selectedUserId && !!onStatusChange && !isPastLocked;

    const isPopoverOpen =
      commentPopover?.date === dateKey &&
      commentPopover?.memberId === member.id;

    const hasComment = comment !== null && comment.length > 0;
    const needsCommentTooltip = hasComment || autoSynced || isPopoverOpen;

    /* 過去日付ロック時は title 属性でロック理由を表示（DOM ネスティング制約のため Tooltip ではなく title を使用） */
    const pastLockTitle =
      isPastLocked && member.id === selectedUserId
        ? t("availability.pastDateLocked")
        : undefined;

    if (needsCommentTooltip) {
      const cell = (
        <CommentTooltip
          key={member.id}
          status={status}
          locale={locale}
          comment={comment}
          autoSynced={autoSynced}
          showInput={isPopoverOpen}
          onSaveComment={(text) =>
            handleCommentSave(dateKey, member.id, text)
          }
          onClose={handleCommentClose}
          onClick={
            isEditable || onCellClick
              ? () => handleCellClick(dateKey, member.id)
              : undefined
          }
          disabled={!isEditable && !onCellClick}
          isSelected={member.id === selectedUserId}
          data-testid={`cell-${dateKey}-${member.id}`}
        />
      );
      return cell;
    }

    return (
      <AvailabilityCell
        key={member.id}
        status={status}
        locale={locale}
        onClick={
          isEditable || onCellClick
            ? () => handleCellClick(dateKey, member.id)
            : undefined
        }
        disabled={!isEditable && !onCellClick}
        isSelected={member.id === selectedUserId}
        data-testid={`cell-${dateKey}-${member.id}`}
        title={pastLockTitle}
      />
    );
  };

  return (
    <Paper
      variant="outlined"
      sx={{ mb: 3, overflow: "hidden" }}
      data-testid="availability-board"
    >
      {/* ヘッダー: ナビゲーション + 月/週切り替え */}
      <Box
        sx={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          flexWrap: "wrap",
          gap: 1,
          p: { xs: 1.5, sm: 2 },
        }}
      >
        {/* 月送りナビゲーション */}
        <Box sx={{ display: "flex", alignItems: "center", gap: 0.5 }}>
          <IconButton
            onClick={handlePrevious}
            size="small"
            aria-label="previous"
            data-testid="nav-previous"
          >
            <ChevronLeftIcon />
          </IconButton>
          <Typography
            variant="h6"
            component="span"
            sx={{ minWidth: 140, textAlign: "center", fontWeight: "bold" }}
            data-testid="nav-header-text"
          >
            {headerText}
          </Typography>
          <IconButton
            onClick={handleNext}
            size="small"
            aria-label="next"
            data-testid="nav-next"
          >
            <ChevronRightIcon />
          </IconButton>
        </Box>

        {/* 月/週切り替え */}
        <MonthWeekToggle viewMode={viewMode} onViewModeChange={setViewMode} />
      </Box>

      <Divider />

      {/* テーブル（レスポンシブ: スマートフォンでは横スクロール） */}
      <Box sx={{ overflowX: "auto" }}>
        <Table size="small" sx={{ minWidth: 400 }} data-testid="board-table">
          <TableHead>
            <TableRow>
              {/* 日付列ヘッダー */}
              <TableCell
                sx={{
                  position: "sticky",
                  left: 0,
                  zIndex: 2,
                  bgcolor: "background.paper",
                  fontWeight: "bold",
                  minWidth: 80,
                }}
              >
                {t("schedule.title")}
              </TableCell>

              {/* 集計列ヘッダー */}
              <TableCell
                align="center"
                sx={{
                  fontWeight: "bold",
                  whiteSpace: "nowrap",
                  fontSize: "0.75rem",
                  px: 0.5,
                }}
                data-testid="summary-header"
              >
                {t("summary.title")}
              </TableCell>

              {/* Core メンバーヘッダー */}
              {coreMembers.map((member) => (
                <TableCell
                  key={member.id}
                  align="center"
                  sx={{
                    fontWeight: "bold",
                    whiteSpace: "nowrap",
                    fontSize: "0.75rem",
                    px: 0.5,
                    bgcolor:
                      member.id === selectedUserId
                        ? "primary.light"
                        : undefined,
                    color:
                      member.id === selectedUserId
                        ? "primary.contrastText"
                        : undefined,
                  }}
                  data-testid={`member-header-${member.id}`}
                >
                  {member.display_name}
                </TableCell>
              ))}

              {/* Core / Sub 区切り */}
              {subMembers.length > 0 && coreMembers.length > 0 && (
                <TableCell
                  sx={{
                    width: 4,
                    px: 0,
                    bgcolor: "divider",
                    borderLeft: "2px solid",
                    borderColor: "divider",
                  }}
                  data-testid="role-divider-header"
                />
              )}

              {/* Sub メンバーヘッダー */}
              {subMembers.map((member) => (
                <TableCell
                  key={member.id}
                  align="center"
                  sx={{
                    fontWeight: "bold",
                    whiteSpace: "nowrap",
                    fontSize: "0.75rem",
                    px: 0.5,
                    bgcolor:
                      member.id === selectedUserId
                        ? "primary.light"
                        : undefined,
                    color:
                      member.id === selectedUserId
                        ? "primary.contrastText"
                        : undefined,
                  }}
                  data-testid={`member-header-${member.id}`}
                >
                  {member.display_name}
                </TableCell>
              ))}
            </TableRow>
          </TableHead>

          <TableBody>
            {dates.map((date) => {
              const dateKey = formatDateKey(date);
              const dayOfWeek = date.getDay();
              const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
              const dateSummary = summary[dateKey];
              const highlight = getRowHighlight(dateSummary, group.threshold_n);
              const highlightColor = ROW_HIGHLIGHT_COLORS[highlight];
              const eventDay = eventDays[dateKey];
              const isEventDay = !!eventDay;
              const past = isPastDate(dateKey);

              /* 行背景色: ハイライト色 > 週末色 > デフォルト */
              const rowBgColor = highlightColor
                ?? (isWeekend ? "action.hover" : undefined);

              return (
                <TableRow
                  key={dateKey}
                  sx={{
                    bgcolor: rowBgColor,
                    /* 過去日付の行は少し透過させて視覚的に区別 */
                    ...(past && { opacity: 0.65 }),
                    /* 活動日の行は左ボーダーで視覚的に区別 */
                    ...(isEventDay && {
                      borderLeft: "3px solid",
                      borderColor: eventDay.confirmed
                        ? "primary.main"
                        : "grey.400",
                    }),
                  }}
                  data-testid={`date-row-${dateKey}`}
                >
                  {/* 日付 + 曜日 + 活動日マーカー */}
                  <TableCell
                    sx={{
                      position: "sticky",
                      left: 0,
                      zIndex: 1,
                      bgcolor: highlightColor
                        ?? (isWeekend ? "grey.100" : "background.paper"),
                      whiteSpace: "nowrap",
                      fontWeight: dayOfWeek === 0 ? "bold" : undefined,
                      color:
                        past
                          ? "text.disabled"
                          : dayOfWeek === 0
                            ? "error.main"
                            : dayOfWeek === 6
                              ? "primary.main"
                              : undefined,
                    }}
                  >
                    {date.getDate()} ({t(`weekday.${dayOfWeek}`)})
                    <EventDayMarker eventDay={eventDay} />
                  </TableCell>

                  {/* 集計セル */}
                  <AvailabilitySummary
                    summary={dateSummary}
                    thresholdN={group.threshold_n}
                    totalMembers={members.length}
                  />

                  {/* Core メンバーのセル */}
                  {coreMembers.map((member) =>
                    renderMemberCell(member, dateKey),
                  )}

                  {/* Core / Sub 区切り */}
                  {subMembers.length > 0 && coreMembers.length > 0 && (
                    <TableCell
                      sx={{
                        width: 4,
                        px: 0,
                        borderLeft: "2px solid",
                        borderColor: "divider",
                      }}
                    />
                  )}

                  {/* Sub メンバーのセル */}
                  {subMembers.map((member) =>
                    renderMemberCell(member, dateKey),
                  )}
                </TableRow>
              );
            })}
          </TableBody>
        </Table>
      </Box>
    </Paper>
  );
}
