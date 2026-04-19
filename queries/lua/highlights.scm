;; extends
;; Better Comments: TODO/WARN/FIXME/NOTE + !/? /* markers
(((comment) @comment (#contains? @comment "TODO")) @comment.warning (#set! priority 150))
(((comment) @comment (#contains? @comment "WARN")) @comment.warning (#set! priority 150))
(((comment) @comment (#contains? @comment "BUGS")) @comment.error (#set! priority 150))
(((comment) @comment (#contains? @comment "FIXME")) @comment.error (#set! priority 150))
(((comment) @comment (#contains? @comment "NOTE")) @comment.note (#set! priority 150))
(((comment) @comment (#match? @comment "--\\s*!")) @comment.error (#set! priority 150))
(((comment) @comment (#match? @comment "--\\s*\\?")) @comment.note (#set! priority 150))
(((comment) @comment (#match? @comment "--\\s*\\*")) @comment.todo (#set! priority 150))
