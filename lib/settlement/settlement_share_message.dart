String settlementShareMessage({required bool refundIssued}) => refundIssued
    ? 'Refund has been issued. Thank you and wish you have a nice day.'
    : 'This is a temporary move-out settlement invoice. The final invoice will be issued after the move-out date, once all final charges have been calculated. Please let me know if you have any questions. Thank you.';
