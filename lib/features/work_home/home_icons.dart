import 'package:flutter/material.dart';

/// Icon names the server may send for a home tile or row (server
/// `lib/app-home.js` ICONS); an unknown or missing name gets a neutral icon.
IconData homeIcon(String? name) => switch (name) {
  'task' => Icons.task_alt,
  'groups' => Icons.groups_2_outlined,
  'calendar' => Icons.event_note,
  'class' => Icons.class_outlined,
  'person_search' => Icons.person_search_outlined,
  'office' => Icons.business_center_outlined,
  'more' => Icons.more_horiz,
  'doc' => Icons.description_outlined,
  'campaign' => Icons.campaign_outlined,
  'edit_note' => Icons.edit_note,
  'web' => Icons.language,
  'event' => Icons.event_available,
  'assignment' => Icons.assignment_outlined,
  'how_to_reg' => Icons.how_to_reg_outlined,
  'fact_check' => Icons.fact_check_outlined,
  'school' => Icons.school_outlined,
  'bell' => Icons.notifications_none,
  'chat' => Icons.chat_bubble_outline,
  'link' => Icons.link,
  _ => Icons.apps,
};
