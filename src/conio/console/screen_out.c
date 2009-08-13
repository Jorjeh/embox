/*
 * screen_out.c
 *
 *  Created on: 28.02.2009
 *      Author: Eldar Abusalimov
 */

#include "screen.h"

#include "terminal.h"
#include "common.h"

static void transmit_string(SCREEN *this, const char *str) {
	while (*str) {
		terminal_transmit(this->terminal, *str++, 0);
	}
}

/*
 * moves screen cursor by specified value
 *
 * param by - delta to move screen cursor by
 */
static void transmit_move_cursor_by(SCREEN *this, int by) {
	if (by == 0) {
		return;
	}

	terminal_transmit(this->terminal, by > 0 ? TERMINAL_TOKEN_CURSOR_RIGHT
			: TERMINAL_TOKEN_CURSOR_LEFT, 1, by > 0 ? by : -by);
}

static void move_cursor_to(SCREEN *this, int col) {
	// TODO range checking

	if (this->cursor + 3 < col || col < this->cursor) {
		// it is more easy to move cursor by special command
		transmit_move_cursor_by(this, col - this->cursor);
		this->cursor = col;
	} else if (this->cursor < col) {
		// rewrite a few chars
		for (; this->cursor < col; ++this->cursor) {
			terminal_transmit(this->terminal, this->string[this->cursor], 0);
		}
	}

}

void screen_out_update(SCREEN *this, CMDLINE *cmdline) {
	if (this == NULL) {
		return;
	}

	int i;
	BOOL dirty = TRUE;

	for (i = 0; cmdline->string[i]; i++) {
		if (this->string[i] == '\0') {
			dirty = FALSE;
		}
		if (!dirty || this->string[i] != cmdline->string[i]) {
			move_cursor_to(this, i);
			assert(i == this->cursor);
			terminal_transmit(this->terminal, cmdline->string[i], 0);
			this->cursor++;
			this->string[i] = cmdline->string[i];
		}
	}

	if (dirty && this->string[i] != '\0') {
		move_cursor_to(this, i);
		terminal_transmit(this->terminal, TERMINAL_TOKEN_ERASE_SCREEN, 1,
				TERMINAL_TOKEN_PARAM_ERASE_DOWN_RIGHT);
	}
	this->string[i] = '\0';

	move_cursor_to(this, cmdline->cursor);
}

void screen_out_puts(SCREEN *this, char *str) {
	if (this == NULL) {
		return;
	}
	if (str != NULL) {
		transmit_string(this, str);
	}
	terminal_transmit(this->terminal, TERMINAL_TOKEN_CR, 0);
	terminal_transmit(this->terminal, TERMINAL_TOKEN_LF, 0);
}

void screen_out_show_prompt(SCREEN *this, const char *prompt) {
	if (this == NULL) {
		return;
	}
	static const char * default_prompt = "";

	this->prompt = (prompt != NULL) ? prompt : default_prompt;

	screen_out_puts(this, NULL);
	*this->string = '\0';
	this->cursor = 0;

	//	screen_set_foreground_color(SGR_COLOR_RED);
	//	terminal_transmit(this->terminal, TERMINAL_TOKEN_CURSOR_SAVE_ATTRS, NULL);
	terminal_transmit(this->terminal, TERMINAL_TOKEN_SGR, 1,
			TERMINAL_TOKEN_PARAM_SGR_FG_RED);
	terminal_transmit(this->terminal, TERMINAL_TOKEN_SGR, 1,
			TERMINAL_TOKEN_PARAM_SGR_INTENSITY_BOLD);

	transmit_string(this, prompt);

	//	terminal_transmit(this->terminal, TERMINAL_TOKEN_CURSOR_RESTORE_ATTRS, NULL);
	terminal_transmit(this->terminal, TERMINAL_TOKEN_SGR, 1,
			TERMINAL_TOKEN_PARAM_SGR_RESET);

	//	screen_set_foreground_color(SGR_COLOR_BLACK);
}
